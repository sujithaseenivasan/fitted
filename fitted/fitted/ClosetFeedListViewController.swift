//
//  ClosetFeedListViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

class ClosetFeedListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var eventId: String!                     //passed from previous screen
    private let db = Firestore.firestore()
    private var items: [[String: Any]] = []  //raw closet item data
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        fetchEventItems()
    }
    
    private func fetchEventItems() {
        db.collection("events").document(eventId).getDocument { [weak self] snap, err in
            guard let self = self else { return }
            if let data = snap?.data(),
               let itemIds = data["event_items"] as? [String] {

                // Fetch each closet item
                self.fetchClosetItems(itemIds: itemIds)
            }
        }
    }
    
    private func fetchClosetItems(itemIds: [String]) {
        let group = DispatchGroup()
        var results: [[String: Any]] = []

        for id in itemIds {
            group.enter()
            db.collection("closet_items").document(id).getDocument { snap, _ in
                if let data = snap?.data() {
                    results.append(data)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.items = results
            self.tableView.reloadData()
        }
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "ClosetFeedCell",
                                                 for: indexPath) as! ClosetFeedCell
        let item = items[indexPath.row]

        cell.nameLabel.text = item["name"] as? String
        cell.brandLabel.text = item["brand"] as? String
        cell.sizeLabel.text = item["size"] as? String

        if let price = item["price"] as? NSNumber {
            cell.priceLabel.text = "$\(price)"
        } else {
            cell.priceLabel.text = ""
        }

        // Title is optional (some people use name only)
        cell.titleLabel.text = item["clothing_type"] as? String

        // Load the item image if stored as a URL string
        if let urlString = item["image"] as? String,
           let url = URL(string: urlString) {

            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        // ensure cell is still visible
                        if let visible = tableView.cellForRow(at: indexPath) as? ClosetFeedCell {
                            visible.itemImage.image = img
                        }
                    }
                }
            }.resume()
        } else {
            cell.itemImage.image = nil
        }

        return cell
    }

}
