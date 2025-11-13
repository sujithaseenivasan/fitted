//
//  GroupSettingsViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit
import FirebaseFirestore

class GroupSettingsViewController: UIViewController {

    @IBOutlet weak var groupPassLabel: UILabel!
    @IBOutlet weak var groupIdLabel: UILabel!
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var group: Group!
    private let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadGroupDetails()
    }
    
    private func loadGroupDetails() {
        db.collection("groups").document(group.id).getDocument { [weak self] snap, _ in
            guard let self = self, let data = snap?.data() else { return }
            
            let name = data["group_name"] as? String ?? ""
            let code = data["id"] as? String ?? ""
            let password = data["password"] as? String ?? ""
            
            DispatchQueue.main.async {
                self.groupNameLabel.text = name
                self.groupIdLabel.text = code
                self.groupPassLabel.text = password
            }
        }
    }
    
    private func presentEditAlert(fieldKey: String,
                                  title: String,
                                  labelToUpdate: UILabel) {
        let alert = UIAlertController(title: "Edit \(title)", message: nil, preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "Enter new \(title.lowercased())"
            tf.text = labelToUpdate.text
        }
        alert.addTextField { tf in
            tf.placeholder = "Confirm new \(title.lowercased())"
            tf.isSecureTextEntry = (fieldKey == "password")
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard
                let first = alert.textFields?[0].text,
                let second = alert.textFields?[1].text,
                !first.isEmpty,
                first == second
            else {
                // If they don't match or are empty, do nothing.
                return
            }
            
            self.db.collection("groups").document(self.group.id)
                .updateData([fieldKey: first]) { error in
                    if let error = error {
                        print("Error updating \(fieldKey): \(error.localizedDescription)")
                        return
                    }
                    DispatchQueue.main.async {
                        labelToUpdate.text = first
                    }
                }
        }
        
        alert.addAction(cancelAction)
        alert.addAction(saveAction)
        
        present(alert, animated: true)
    }
    
    @IBAction func passChangePressed(_ sender: Any) {
        presentEditAlert(fieldKey: "password",
                         title: "Password",
                         labelToUpdate: groupPassLabel)
    }
    
    @IBAction func IdChangePressed(_ sender: Any) {
        presentEditAlert(fieldKey: "id",
                         title: "ID",
                         labelToUpdate: groupIdLabel)
    }
    
    @IBAction func nameChangePressed(_ sender: Any) {
        presentEditAlert(fieldKey: "group_name",
                         title: "Name",
                         labelToUpdate: groupNameLabel)
    }
    
    @IBAction func manageButtonPressed(_ sender: Any) {
    }
    
    @IBAction func editImagePressed(_ sender: Any) {
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
