//
//  ClosetShareGroupsViewController.swift
//  fitted
//
//  Created by Sarah Neville on 10/6/25.
//

import UIKit
import FirebaseFirestore
import FirebaseCore

class ClosetShareGroupsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    

    @IBOutlet weak var joinGroupButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
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
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return groups.count
    }
    
    //dequeue a cell and populate it with group's data
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                            for: indexPath) as? GroupCardCell else {
            return UICollectionViewCell()
        }
        //populate group cell
        let group = groups[indexPath.item]
        cell.titleLabel.text = group.name
        // TODO: implement image handling, this is fine for now
        cell.logoImageView.image = nil
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

}
