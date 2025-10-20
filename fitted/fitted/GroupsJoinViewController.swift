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
        // Basic validation of input
        guard let groupId = groupIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !groupId.isEmpty else {
            showAlert(title: "Error", message: "Please enter a group ID.")
            return
        }
        let enteredPassword = passwordField.text ?? ""

        // Fetch the group document by the entered groupId
        let groupRef = db.collection("groups").document(groupId)
        groupRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.showAlert(title: "Error", message: "Failed to fetch group: \(error.localizedDescription)")
                return
            }

            guard let doc = snapshot, doc.exists, let data = doc.data() else {
                self.showAlert(title: "Invalid Group", message: "No group found with that ID.")
                return
            }

            // Compare stored password (if any). If stored password is missing or empty, accept.
            let storedPassword = (data["group_password"] as? String) ?? ""
            if !storedPassword.isEmpty && storedPassword != enteredPassword {
                self.showAlert(title: "Wrong Password", message: "The password you entered is incorrect.")
                return
            }

            // Ensure user is signed in (we need a UID). If not signed in, show error.
            guard let uid = Auth.auth().currentUser?.uid else {
                self.showAlert(title: "Not Signed In", message: "You must be signed in to join a group.")
                return
            }

            // Add groupId to user's joined_groups array (creates field if it doesn't exist)
            let userRef = self.db.collection("users").document(uid)
            userRef.updateData(["joined_groups": FieldValue.arrayUnion([groupId])]) { err in
                if let err = err {
                    // If the user doc doesn't exist, create it with joined_groups
                    if (err as NSError).code == FirestoreErrorCode.notFound.rawValue {
                        userRef.setData(["joined_groups": [groupId]]) { setErr in
                            if let setErr = setErr {
                                self.showAlert(title: "Error", message: "Failed to add group: \(setErr.localizedDescription)")
                            } else {
                                self.showAlert(title: "Joined", message: "Successfully joined the group.")
                            }
                        }
                    } else {
                        self.showAlert(title: "Error", message: "Failed to add group: \(err.localizedDescription)")
                    }
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

