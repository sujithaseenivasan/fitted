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
        removeMember(member, at: indexPath)
    }
    
    private func removeMember(_ member: Member, at indexPath: IndexPath) {
        let memberUid = member.uid
        let groupRef = db.collection("groups").document(groupId)
        let userRef  = db.collection("users").document(memberUid)

        // Step 1: read the group to get its events array
        groupRef.getDocument { [weak self] snap, error in
            guard let self = self else { return }

            if let error = error {
                print("Error loading group for removal:", error.localizedDescription)
                return
            }

            let data = snap?.data() ?? [:]
            let eventIds = data["events"] as? [String] ?? []

            // Step 1 & 2: remove member from group_members and groupId from joinedGroups
            let batch = self.db.batch()
            batch.updateData(
                ["group_members": FieldValue.arrayRemove([memberUid])],
                forDocument: groupRef
            )
            batch.updateData(
                ["joinedGroups": FieldValue.arrayRemove([self.groupId as Any])],
                forDocument: userRef
            )

            batch.commit { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    print("Failed to remove member from group/joinedGroups:", error.localizedDescription)
                    return
                }

                // Now clean up items + requests for this member across the group's events
                self.cleanupMemberData(memberUid: memberUid, eventIds: eventIds) {
                    // Finally update UI
                    self.members.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            }
        }
    }
    
    private func cleanupMemberData(memberUid: String,
                                   eventIds: [String],
                                   completion: @escaping () -> Void) {
        guard !eventIds.isEmpty else {
            completion()
            return
        }

        let outerGroup = DispatchGroup()
        let requestsCollection = db.collection("requests")
        let itemsCollection = db.collection("closet_items")

        for eventId in eventIds {
            outerGroup.enter()

            let eventRef = db.collection("events").document(eventId)

            // Load the event doc so we can see event_items
            eventRef.getDocument { [weak self] eventSnap, error in
                guard let self = self else {
                    outerGroup.leave()
                    return
                }

                if let error = error {
                    print("Error loading event \(eventId):", error.localizedDescription)
                    outerGroup.leave()
                    return
                }

                let eventData = eventSnap?.data() ?? [:]
                let eventItemIds = eventData["event_items"] as? [String] ?? []

                // 3) Figure out which event_items belong to this member (via closet_items.owner)
                var itemIdsToRemove: [String] = []
                let innerGroup = DispatchGroup()

                for itemId in eventItemIds {
                    innerGroup.enter()
                    itemsCollection.document(itemId).getDocument { itemSnap, _ in
                        if let itemData = itemSnap?.data(),
                           let owner = itemData["owner"] as? String,
                           owner == memberUid {
                            itemIdsToRemove.append(itemId)
                        }
                        innerGroup.leave()
                    }
                }

                innerGroup.notify(queue: .global()) {
                    // 4) Find all requests for this member in this event (incoming + outgoing)
                    let requestsGroup = DispatchGroup()
                    var requestsToDelete: [DocumentReference] = []

                    // As owner
                    requestsGroup.enter()
                    requestsCollection
                        .whereField("eventId", isEqualTo: eventId)
                        .whereField("ownerId", isEqualTo: memberUid)
                        .getDocuments { snap, _ in
                            if let docs = snap?.documents {
                                for doc in docs {
                                    requestsToDelete.append(doc.reference)
                                }
                            }
                            requestsGroup.leave()
                        }

                    // As requester
                    requestsGroup.enter()
                    requestsCollection
                        .whereField("eventId", isEqualTo: eventId)
                        .whereField("requesterId", isEqualTo: memberUid)
                        .getDocuments { snap, _ in
                            if let docs = snap?.documents {
                                for doc in docs {
                                    requestsToDelete.append(doc.reference)
                                }
                            }
                            requestsGroup.leave()
                        }

                    requestsGroup.notify(queue: .global()) {
                        let batch = self.db.batch()

                        // Unhook items from this event (do NOT delete the closet_items docs)
                        if !itemIdsToRemove.isEmpty {
                            batch.updateData(
                                ["event_items": FieldValue.arrayRemove(itemIdsToRemove)],
                                forDocument: eventRef
                            )
                        }

                        // Delete the relevant request docs
                        for ref in requestsToDelete {
                            batch.deleteDocument(ref)
                        }

                        batch.commit { error in
                            if let error = error {
                                print("Error cleaning up event \(eventId) for member \(memberUid):",
                                      error.localizedDescription)
                            }
                            outerGroup.leave()
                        }
                    }
                }
            }
        }

        outerGroup.notify(queue: .main) {
            completion()
        }
    }


}
