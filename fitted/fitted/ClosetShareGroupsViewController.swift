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
    
    //fetches all documents in "groups" collection in firebase
    func fetchGroups() {
        
        db.collection("groups").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            //handle errors
            if let error = error {
                print("Error fetching groups:", error.localizedDescription)
                return
            }
            // guard snapshot and map documents to Group models
            guard let docs = snapshot?.documents else { return }
            var loaded: [Group] = []
            for doc in docs {
                if let g = Group(id: doc.documentID, dict: doc.data()) {
                    loaded.append(g)
                }
            }
            // sort by name for consistent ordering
            self.groups = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            // reload UI on main thread
            DispatchQueue.main.async {
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
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                            for: indexPath) as? GroupCardCell else {
            return UICollectionViewCell()
        }

        let group = groups[indexPath.item]
        cell.titleLabel.text = group.name
        // in cellForItemAt
        cell.logoImageView.image = nil
        if let path = group.imagePath {
            let currentIndexPath = indexPath
            loadImage(from: path) { image in
                DispatchQueue.main.async {
                    if let visible = collectionView.cellForItem(at: currentIndexPath) as? GroupCardCell {
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
