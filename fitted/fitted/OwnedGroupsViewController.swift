//
//  OwnedGroupsViewController.swift
//  fitted
//
//  Created by Sujitha Seenivasan on 11/12/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class OwnedGroupsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!

    private var groups: [Group] = []
    private let db = Firestore.firestore()
    private let reuseIdentifier = "GroupCardCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = self
        collectionView.delegate = self

        // spacing so last cell isn't under tab bar
        collectionView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 80, right: 0)

        fetchOwnedGroups()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchOwnedGroups()   // refresh every time user comes back
    }

    // MARK: - Firestore fetch

    func fetchOwnedGroups() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No signed-in user; cannot load owned groups.")
            groups = []
            collectionView.reloadData()
            return
        }

        // 1) Read the user's owned_groups (array of group doc IDs)
        db.collection("users").document(uid).getDocument { [weak self] snap, err in
            guard let self = self else { return }

            if let err = err {
                print("Error fetching user doc: \(err.localizedDescription)")
                self.groups = []
                self.collectionView.reloadData()
                return
            }

            let data = snap?.data() ?? [:]
            let ownedIds = data["owned_groups"] as? [String] ?? []
            guard !ownedIds.isEmpty else {
                self.groups = []
                self.collectionView.reloadData()
                return
            }

            // 2) Fetch those group docs by ID (chunk into batches of ≤ 10 for 'in' queries)
            var loaded: [Group] = []
            let dispatchGroup = DispatchGroup()

            let chunks: [[String]] = stride(from: 0, to: ownedIds.count, by: 10).map {
                Array(ownedIds[$0 ..< min($0 + 10, ownedIds.count)])
            }

            for chunk in chunks {
                dispatchGroup.enter()
                self.db.collection("groups")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments { snap, err in
                        if let err = err {
                            print("Error fetching owned groups chunk: \(err.localizedDescription)")
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

            dispatchGroup.notify(queue: .main) {
                self.groups = loaded.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                self.collectionView.reloadData()
            }
        }
    }

    // MARK: - Storage image helper

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

    // MARK: - CollectionView data source

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return groups.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier,
            for: indexPath
        ) as? GroupCardCell else {
            return UICollectionViewCell()
        }

        let group = groups[indexPath.item]
        cell.titleLabel.text = group.name

        // reset
        cell.logoImageView.image = nil
        cell.logoImageView.contentMode = .scaleAspectFit
        cell.logoImageView.clipsToBounds = true

        let currentGroupId = group.id

        if let path = group.imagePath {
            loadImage(from: path) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
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

    // MARK: - Layout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets = self.collectionView(collectionView,
                                         layout: collectionViewLayout,
                                         insetForSectionAt: indexPath.section)
        let width = collectionView.bounds.width - (insets.left + insets.right)
        let height: CGFloat = 200
        return CGSize(width: width, height: height)
    }

    // MARK: - Context menu for delete

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {

        let group = groups[indexPath.item]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let delete = UIAction(
                title: "Delete Group",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self.confirmDelete(group: group, indexPath: indexPath)
            }
            return UIMenu(children: [delete])
        }
    }

    private func confirmDelete(group: Group, indexPath: IndexPath) {
        let ac = UIAlertController(
            title: "Delete “\(group.name)”?",
            message: "This will remove the group for all members.",
            preferredStyle: .alert
        )
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.delete(group: group, indexPath: indexPath)
        })
        present(ac, animated: true)
    }

    private func delete(group: Group, indexPath: IndexPath) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let groupId = group.id
        let groupRef = db.collection("groups").document(groupId)

        // 1) Delete optional image from Storage
        if let path = group.imagePath {
            let storageRef = Storage.storage().reference(forURL: path)
            storageRef.delete { error in
                if let error = error {
                    print("Error deleting group image:", error.localizedDescription)
                }
            }
        }

        // 2) Delete group document
        groupRef.delete { err in
            if let err = err {
                print("Error deleting group doc:", err.localizedDescription)
                return
            }

            // 3) Remove ID from user's owned_groups
            self.db.collection("users").document(uid)
                .updateData(["owned_groups": FieldValue.arrayRemove([groupId])]) { err2 in
                    if let err2 = err2 {
                        print("Error updating owned_groups:", err2.localizedDescription)
                    }

                    // 4) Update local model + UI
                    DispatchQueue.main.async {
                        if self.groups.indices.contains(indexPath.item) {
                            self.groups.remove(at: indexPath.item)
                        }
                        UIView.performWithoutAnimation {
                            self.collectionView.reloadData()
                            self.collectionView.layoutIfNeeded()
                        }
                    }
                }
        }
    }

    // MARK: - Tap → open group settings

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        
    }
}
