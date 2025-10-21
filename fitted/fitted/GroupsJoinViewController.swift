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
        let enteredPassword = (passwordField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        db.collection("groups")
            .whereField("id", isEqualTo: code)
            .limit(to: 1)
            .getDocuments { [weak self] snap, err in
                guard let self = self else { return }

                if let err = err {
                    self.showAlert(title: "Error", message: err.localizedDescription)
                    return
                }

                guard let doc = snap?.documents.first else {
                    self.showAlert(title: "Invalid Group", message: "No group found with that ID.")
                    return
                }

                let data = doc.data()
                let storedPassword = data["password"] as? String ?? ""
                if !storedPassword.isEmpty && storedPassword != enteredPassword {
                    self.showAlert(title: "Wrong Password", message: "The password you entered is incorrect.")
                    return
                }

                guard let uid = Auth.auth().currentUser?.uid else {
                    self.showAlert(title: "Not Signed In", message: "You must be signed in to join a group.")
                    return
                }

                let groupDocId = doc.documentID
                let userRef = self.db.collection("users").document(uid)

                userRef.setData(["joinedGroups": FieldValue.arrayUnion([groupDocId])],
                                merge: true) { writeErr in
                    if let writeErr = writeErr {
                        self.showAlert(title: "Error", message: "Failed to add group: \(writeErr.localizedDescription)")
                        return
                    }

                    // Success alert that also pops back
                    DispatchQueue.main.async {
                        let ac = UIAlertController(
                            title: "Joined",
                            message: "Successfully joined the group.",
                            preferredStyle: .alert
                        )
                        ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            // Go back once the alert is dismissed
                            self.navigationController?.popViewController(animated: true)
                        })
                        self.present(ac, animated: true, completion: nil)
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

