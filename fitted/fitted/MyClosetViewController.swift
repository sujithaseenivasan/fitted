//
//  MyClosetViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

struct ClosetItem {
    let name: String
    let imageURL: String?
}

class MyClosetViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView! //TODO: actually connect this to the storyboard

    private let db = Firestore.firestore()
    private var items: [ClosetItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        fetchMyCloset()
    }
    
    private func fetchMyCloset() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
            guard let self = self else { return }
            guard let data = snap?.data(),
                  let itemIds = data["my_closet"] as? [String],
                  !itemIds.isEmpty else {
                return
            }
            self.fetchClosetItems(ids: itemIds)
        }
    }
    
    private func fetchClosetItems(ids: [String]) {
        let group = DispatchGroup()
        var results: [ClosetItem] = []

        for id in ids {
            group.enter()
            db.collection("closet_items").document(id).getDocument { snap, _ in
                if let data = snap?.data() {
                    let name = data["name"] as? String ?? ""
                    let imageURL = data["image"] as? String
                    results.append(ClosetItem(name: name, imageURL: imageURL))
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.items = results
            self.collectionView.reloadData()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ClosetItemCell",
                                                      for: indexPath) as! ClosetItemCell
        let item = items[indexPath.item]
        cell.titleLabel.text = item.name
        cell.imageView.image = nil

        if let urlString = item.imageURL, let url = URL(string: urlString) {
            let targetIndexPath = indexPath
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if let visible = collectionView.cellForItem(at: targetIndexPath) as? ClosetItemCell {
                            visible.imageView.image = img
                        }
                    }
                }
            }.resume()
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let itemsPerRow: CGFloat = 3
        let padding: CGFloat = 16   // side spacing
        let interItemSpacing: CGFloat = 12

        let totalHorizontalPadding = padding * 2 + interItemSpacing * (itemsPerRow - 1)
        let availableWidth = collectionView.bounds.width - totalHorizontalPadding
        let itemWidth = floor(availableWidth / itemsPerRow)

        // image square + extra space for label
        return CGSize(width: itemWidth, height: itemWidth + 50)
    }


}
