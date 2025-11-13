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

                        let profilePath = userData["profilePicture"] as? String
                        loaded.append(Member(name: fullName.isEmpty ? "Unknown" : fullName,
                                             profileImagePath: profilePath))
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
    
    
    private func loadImage(from storagePath: String, completion: @escaping (UIImage?) -> Void) {
        let ref = Storage.storage().reference(forURL: storagePath)
        ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
            if let data = data, error == nil, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
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

}
