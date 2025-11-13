//
//  CreateGroupViewController.swift
//  fitted
//
//  Created by Sujitha Seenivasan on 11/12/25.
//

import UIKit
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class CreateGroupViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var groupNameTextField: UITextField!
    @IBOutlet weak var groupIdTextField: UITextField!          // human-readable id (stored in "id" field)
    @IBOutlet weak var groupPasscodeTextField: UITextField!
    @IBOutlet weak var groupDescriptionTextField: UITextView!
    @IBOutlet weak var groupPhotoImageView: UIImageView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        groupPhotoImageView.contentMode = .scaleAspectFill
        groupPhotoImageView.clipsToBounds = true
        groupPhotoImageView.layer.cornerRadius = 8

        groupDescriptionTextField.layer.cornerRadius = 8
        groupDescriptionTextField.layer.borderWidth = 0.5
        groupDescriptionTextField.layer.borderColor = UIColor.systemGray4.cgColor
    }

    // MARK: - Actions

    @IBAction func uploadGroupPhotoButtonPressed(_ sender: Any) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func createGroupButtonPressed(_ sender: Any) {
        createGroup()
    }

    // MARK: - Core logic

    private func createGroup() {
        guard
            let currentUser = Auth.auth().currentUser,
            let name = groupNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            let humanReadableId = groupIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            let passcode = groupPasscodeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty,
            !humanReadableId.isEmpty,
            !passcode.isEmpty
        else {
            showSimpleAlert(title: "Missing Info",
                            message: "Please fill in group name, id, and passcode.")
            return
        }

        let description = groupDescriptionTextField.text ?? ""
        let db = Firestore.firestore()

        // Create a new document with an auto-generated ID.
        let groupDocRef = db.collection("groups").document()
        let groupDocId = groupDocRef.documentID   // THIS is what will go in owned_groups

        // Helper: finalize Firestore writes after (optional) image upload
        func finishCreateGroup(imagePath: String?) {
            var groupData: [String: Any] = [
                "description": description,
                "events": [String](),             // start with empty events array
                "group_members": [currentUser.uid],
                "group_name": name,
                "id": humanReadableId,            // your text field -> "id" field
                "owner": currentUser.uid,
                "password": passcode
            ]
            if let path = imagePath {
                groupData["image"] = path         // match Firestore field name "image"
            }

            // 1) Save to groups/<auto doc id>
            groupDocRef.setData(groupData) { error in
                if let error = error {
                    print("Error saving group:", error.localizedDescription)
                    self.showSimpleAlert(title: "Error",
                                         message: "Couldn't create group. Please try again.")
                    return
                }

                // 2) Append *document id* to users/{uid}.owned_groups
                db.collection("users").document(currentUser.uid)
                    .setData(["owned_groups": FieldValue.arrayUnion([groupDocId])],
                             merge: true) { err in
                        if let err = err {
                            print("Error updating owned_groups:", err.localizedDescription)
                        }
                        DispatchQueue.main.async {
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
            }
        }

        // If image exists, upload to Storage first, else just create Firestore doc
        if let image = groupPhotoImageView.image,
           let data = image.jpegData(compressionQuality: 0.85) {

            // store image under the *document id* so it matches the ownership reference
            let storageRef = Storage.storage()
                .reference()
                .child("group_photos/\(groupDocId).jpg")

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            storageRef.putData(data, metadata: metadata) { _, error in
                if let error = error {
                    print("Error uploading group photo:", error.localizedDescription)
                    // Still create group without image path
                    finishCreateGroup(imagePath: nil)
                    return
                }

                // If you want a gs:// style path similar to your screenshot:
                // let path = "gs://\(Storage.storage().reference().bucket)/group_photos/\(groupDocId).jpg"
                // finishCreateGroup(imagePath: path)

                // Or if you prefer https download URL instead, you can use:
                storageRef.downloadURL { url, _ in
                    let path = url?.absoluteString
                    finishCreateGroup(imagePath: path)
                }
            }
        } else {
            // No photo selected
            finishCreateGroup(imagePath: nil)
        }
    }

    // MARK: - Helpers

    private func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PHPicker Delegate

extension CreateGroupViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController,
                didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self = self, let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self.groupPhotoImageView.image = image
            }
        }
    }
}
