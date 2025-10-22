//
//  ClosetShareGroupsViewController.swift
//  fitted
//
//  Created by Sarah Neville on 10/6/25.
//

import UIKit
import FirebaseFirestore
import FirebaseCore
import FirebaseAuth
import FirebaseStorage

class ClosetShareGroupsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    

    @IBOutlet weak var joinGroupButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var logoutButton: UIButton!
    private var groups: [Group] = []
    private let db = Firestore.firestore()
    private let reuseIdentifier = "GroupCardCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        
        //pacing so last cell isn't under tab bar
        collectionView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 80, right: 0)

        fetchGroups()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchGroups()   // refresh list every time user returns
    }

    
    //fetches all documents in "groups" collection in firebase
    func fetchGroups() {
        // Must have a signed-in user
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No signed-in user; cannot load joined groups.")
            self.groups = []
            self.collectionView.reloadData()
            return
        }

        // 1) Read the user's joinedGroups (array of group doc IDs)
        db.collection("users").document(uid).getDocument { [weak self] snap, err in
            guard let self = self else { return }

            if let err = err {
                print("Error fetching user doc: \(err.localizedDescription)")
                self.groups = []
                self.collectionView.reloadData()
                return
            }

            let data = snap?.data() ?? [:]
            let joinedIds = data["joinedGroups"] as? [String] ?? []   // ← field name per your schema
            guard !joinedIds.isEmpty else {
                // User hasn't joined any groups
                self.groups = []
                self.collectionView.reloadData()
                return
            }

            // 2) Fetch those group docs by ID (batch in chunks of ≤10 for 'in' queries)
            var loaded: [Group] = []
            let dispatchGroup = DispatchGroup()

            let chunks: [[String]] = stride(from: 0, to: joinedIds.count, by: 10).map {
                Array(joinedIds[$0..<min($0 + 10, joinedIds.count)])
            }

            for chunk in chunks {
                dispatchGroup.enter()
                self.db.collection("groups")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments { snap, err in
                        if let err = err {
                            print("Error fetching groups chunk: \(err.localizedDescription)")
                        } else if let docs = snap?.documents {
                            for doc in docs {
                                if let g = Group(id: doc.documentID, dict: doc.data()) {
                                    loaded.append(g)
                                }
                            }
                        }
                        dispatchGroup.leave()
                    }
            }

            // 3) When all chunks complete, sort and reload UI
            dispatchGroup.notify(queue: .main) {
                self.groups = loaded.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                self.collectionView.reloadData()
            }
        }
    }

    
    private func loadImage(from storagePath: String, completion: @escaping (UIImage?) -> Void) {
        let storageRef = Storage.storage().reference(forURL: storagePath)
        storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                completion(nil)
                return
            }
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return groups.count
    }
    
    //dequeue a cell and populate it with group's data
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                            for: indexPath) as? GroupCardCell else {
            return UICollectionViewCell()
        }

        let group = groups[indexPath.item]
        cell.titleLabel.text = group.name

        // reset every reuse
        cell.logoImageView.image = nil
        cell.logoImageView.contentMode = .scaleAspectFit
        cell.logoImageView.clipsToBounds = true

        // capture the model id to validate later
        let currentGroupId = group.id

        if let path = group.imagePath {
            loadImage(from: path) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    // Find the current indexPath for this cell and confirm the model id matches
                    if let visible = collectionView.cellForItem(at: indexPath) as? GroupCardCell,
                       self.groups.indices.contains(indexPath.item),
                       self.groups[indexPath.item].id == currentGroupId {
                        visible.logoImageView.image = image
                    }
                }
            }
        }

        return cell
    }

    
    //layout one card per row
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets = self.collectionView(collectionView, layout: collectionViewLayout, insetForSectionAt: indexPath.section)
        let width = collectionView.bounds.width - (insets.left + insets.right)
        let height: CGFloat = 200
        return CGSize(width: width, height: height)
    }
    
    // iOS 13+
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {

        let group = groups[indexPath.item]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let leave = UIAction(
                title: "Leave Group",
                image: UIImage(systemName: "person.crop.circle.badge.minus"),
                attributes: .destructive
            ) { _ in
                self.confirmLeave(group: group, indexPath: indexPath)
            }
            return UIMenu(children: [leave])
        }
    }
    
    private func confirmLeave(group: Group, indexPath: IndexPath) {
        let ac = UIAlertController(
            title: "Leave “\(group.name)”?",
            message: "You’ll be removed from this group.",
            preferredStyle: .alert
        )
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Leave", style: .destructive) { _ in
            self.leave(group: group, indexPath: indexPath)
        })
        present(ac, animated: true)
    }

    private func leave(group: Group, indexPath: IndexPath) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid)
          .updateData(["joinedGroups": FieldValue.arrayRemove([group.id])]) { err in
            DispatchQueue.main.async {
                guard err == nil else { print(err!.localizedDescription); return }

                // Update model
                self.groups.remove(at: indexPath.item)

                // Hard refresh with animations disabled to avoid the “zoom” flicker
                UIView.performWithoutAnimation {
                    self.collectionView.reloadData()
                    self.collectionView.layoutIfNeeded()
                }
            }
        }
    }
    
    @IBAction func logoutButtonPressed(_ sender: Any) {
    do {
            try Auth.auth().signOut()
            print("User logged out successfully.")
            
            navigationController?.popToRootViewController(animated: true)

        } catch let signOutError as NSError {
            print("Error signing out:", signOutError.localizedDescription)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedGroup = groups[indexPath.item]
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "EventLineupViewController") as! EventLineupViewController
        vc.groupId = selectedGroup.id           // ← pass the group doc ID
        navigationController?.pushViewController(vc, animated: true)
    }

}
