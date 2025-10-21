//
//  GroupsJoinViewController.swift
//  fitted
//
//  Created by Sarah Neville on 10/6/25.
//
import UIKit
import FirebaseAuth
import FirebaseFirestore

class GroupsJoinViewController: UIViewController {

    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var groupIdField: UITextField!

    private let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // join button pressed
    @IBAction func joinButtonTapped(_ sender: UIButton) {
        guard let code = groupIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else {
            showAlert(title: "Error", message: "Please enter a group ID.")
            return
        }
        let enteredPassword = passwordField.text ?? ""

        // 1) Find the group by its human-friendly code in field "id"
        db.collection("groups")
          .whereField("id", isEqualTo: code)
          .limit(to: 1)
          .getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err { self.showAlert(title: "Error", message: err.localizedDescription); return }
            guard let doc = snap?.documents.first else {
                self.showAlert(title: "Invalid Group", message: "No group found with that ID.")
                return
            }

            let data = doc.data()
            let storedPassword = data["password"] as? String ?? ""   // ← matches your schema
            if !storedPassword.isEmpty && storedPassword != enteredPassword {
                self.showAlert(title: "Wrong Password", message: "The password you entered is incorrect.")
                return
            }

            guard let uid = Auth.auth().currentUser?.uid else {
                self.showAlert(title: "Not Signed In", message: "You must be signed in to join a group.")
                return
            }

            // 2) Save the Firestore **document ID** to the user’s joined_groups
            let groupDocId = doc.documentID
            let userRef = self.db.collection("users").document(uid)
            userRef.updateData(["joined_groups": FieldValue.arrayUnion([groupDocId])]) { updateErr in
                if let updateErr = updateErr as NSError?, updateErr.code == FirestoreErrorCode.notFound.rawValue {
                    userRef.setData(["joined_groups": [groupDocId]]) { setErr in
                        setErr == nil
                          ? self.showAlert(title: "Joined", message: "Successfully joined the group.")
                          : self.showAlert(title: "Error", message: "Failed to add group: \(setErr!.localizedDescription)")
                    }
                } else if let updateErr = updateErr {
                    self.showAlert(title: "Error", message: "Failed to add group: \(updateErr.localizedDescription)")
                } else {
                    self.showAlert(title: "Joined", message: "Successfully joined the group.")
                }
            }
        }
    }

    //helper for displaying alerts
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(ac, animated: true, completion: nil)
        }
    }
}

