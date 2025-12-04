//
//  ManageMembersViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/13/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

struct Member {
    let uid: String
    let name: String
    let profileImagePath: String?
}

class ManageMembersViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var groupId: String!  // set this before pushing this VC
    private let db = Firestore.firestore()
    private var members: [Member] = []

    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 72  // or whatever height you want
        tableView.tableFooterView = UIView()
        fetchMembers()
    }
    
    private func fetchMembers() {
        db.collection("groups").document(groupId).getDocument { [weak self] snap, _ in
            guard let self = self, let data = snap?.data() else { return }
            guard let memberIds = data["group_members"] as? [String], !memberIds.isEmpty else {
                return
            }

            let usersRef = self.db.collection("users")
            var loaded: [Member] = []
            let group = DispatchGroup()

            for uid in memberIds {
                group.enter()
                usersRef.document(uid).getDocument { userSnap, _ in
                    if let userData = userSnap?.data() {
                        let first = userData["firstName"] as? String ?? ""
                        let last  = userData["lastName"]  as? String ?? ""
                        let fullName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")

                        let profilePath = userData["profilePictureURL"] as? String
                        let member = Member(
                            uid: uid,
                            name: fullName.isEmpty ? "Unknown" : fullName,
                            profileImagePath: profilePath
                        )
                        loaded.append(member)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.members = loaded
                self.tableView.reloadData()
            }
        }
    }
    
    
    private func loadImage(from path: String, completion: @escaping (UIImage?) -> Void) {
        // gs:// path → Firebase Storage
        if path.hasPrefix("gs://") {
            let ref = Storage.storage().reference(forURL: path)
            ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                guard let data = data, error == nil,
                      let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                completion(image)
            }

        // https:// path → normal URLSession
        } else if let url = URL(string: path) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data,
                      let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                completion(image)
            }.resume()

        } else {
            completion(nil)
        }
    }

    
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return members.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MemberTableViewCell",
                                                 for: indexPath) as! MemberTableViewCell
        let member = members[indexPath.row]
        cell.nameLabel.text = member.name
        cell.profileImage.image = nil

        if let path = member.profileImagePath {
            let targetIndexPath = indexPath
            loadImage(from: path) { image in
                DispatchQueue.main.async {
                    if let visible = tableView.cellForRow(at: targetIndexPath) as? MemberTableViewCell {
                        visible.profileImage.image = image
                    }
                }
            }
        }

        return cell
    }
    
    // Allow swipe-to-delete
    func tableView(_ tableView: UITableView,
                   canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }

        let member = members[indexPath.row]
        let batch = db.batch()

        // 1) groups/{groupId} → remove member.uid from group_members
        let groupRef = db.collection("groups").document(groupId)
        batch.updateData([
            "group_members": FieldValue.arrayRemove([member.uid])
        ], forDocument: groupRef)

        // 2) users/{member.uid} → remove this groupId from joinedGroups
        let userRef = db.collection("users").document(member.uid)
        batch.updateData([
            "joinedGroups": FieldValue.arrayRemove([groupId as Any])
        ], forDocument: userRef)

        // 3) events/{groupId} → remove member.uid from group_members
        let eventGroupRef = db.collection("events").document(groupId)
        batch.updateData([
            "group_members": FieldValue.arrayRemove([member.uid])
        ], forDocument: eventGroupRef)

        batch.commit { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print("Failed to remove member: \(error.localizedDescription)")
                // optional: show alert here
                return
            }

            // Update local data + UI
            self.members.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }



}
