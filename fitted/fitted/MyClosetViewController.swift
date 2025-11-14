//
//  MyClosetViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct ClosetItem {
    let id: String
    let name: String
    let imageURL: String?
}

class MyClosetViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView!

    private let db = Firestore.firestore()
    private var items: [ClosetItem] = []
    var selectionEventId: String?
    var onItemAddedToEvent: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        fetchMyCloset()
        
        let longPress = UILongPressGestureRecognizer(target: self,
                                                     action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchMyCloset()
    }

    
    private func fetchMyCloset() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
            guard let self = self else { return }
            guard let data = snap?.data(),
                  let itemIds = data["my_closet"] as? [String],
                  !itemIds.isEmpty else {
                // no items -> clear and reload
                self.items = []
                self.collectionView.reloadData()
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
                    results.append(ClosetItem(id: id, name: name, imageURL: imageURL))
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

        if let urlString = item.imageURL {
            let targetIndexPath = indexPath

            if urlString.hasPrefix("gs://") {
                // Firebase Storage path
                let ref = Storage.storage().reference(forURL: urlString)
                ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                    guard let data = data, error == nil,
                          let img = UIImage(data: data) else { return }
                    DispatchQueue.main.async {
                        if let visible = collectionView.cellForItem(at: targetIndexPath) as? ClosetItemCell {
                            visible.imageView.image = img
                        }
                    }
                }
            } else if let url = URL(string: urlString) {
                // Regular https URL
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
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        let item = items[indexPath.item]

        guard let eventId = selectionEventId else {
            return   // normal MyCloset behavior
        }

        let alert = UIAlertController(
            title: "Add Item?",
            message: "Upload \"\(item.name)\" to this event?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self else { return }

            self.db.collection("events").document(eventId)
                .setData([
                    "event_items": FieldValue.arrayUnion([item.id])
                ], merge: true) { error in
                    if let error = error {
                        print("Failed to add item to event: \(error.localizedDescription)")
                        return
                    }

                    // tell whoever presented this VC that an item was added
                    self.onItemAddedToEvent?()

                    // dismiss this picker
                    self.dismiss(animated: true)
                }
        })

        present(alert, animated: true)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // only trigger once when the press begins
        if gesture.state != .began { return }
        
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        
        let item = items[indexPath.item]
        
        let alert = UIAlertController(
            title: "Delete Item",
            message: "Are you sure you want to delete \"\(item.name)\" from your closet?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteItem(at: indexPath)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteItem(at indexPath: IndexPath) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let item = items[indexPath.item]
        let itemRef = db.collection("closet_items").document(item.id)
        let userRef = db.collection("users").document(uid)
        
        let batch = db.batch()
        batch.deleteDocument(itemRef)
        batch.updateData(["my_closet": FieldValue.arrayRemove([item.id])], forDocument: userRef)
        
        batch.commit { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("Error deleting item: \(error.localizedDescription)")
                return
            }
            
            // update local array + UI
            self.items.remove(at: indexPath.item)
            self.collectionView.performBatchUpdates({
                self.collectionView.deleteItems(at: [indexPath])
            }, completion: nil)
        }
    }

}
