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
    
    private var userNameCache: [String: String] = [:]  // [uid: name]
    private let usersRef = Firestore.firestore().collection("users")

    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
        
        fetchEventItems()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchEventItems()
    }
    
    func fetchEventItems() {
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

        cell.brandLabel.text = item["brand"] as? String
        cell.sizeLabel.text = item["size"] as? String

        if let price = item["price"] as? NSNumber {
            cell.priceLabel.text = "$\(price)"
        } else {
            cell.priceLabel.text = ""
        }
        
        if let ownerUID = item["owner"] as? String {

            if let cachedName = userNameCache[ownerUID] {
                cell.nameLabel.text = cachedName
            } else {
                usersRef.document(ownerUID).getDocument { [weak self] snap, _ in
                    guard let self = self else { return }

                    let data = snap?.data() ?? [:]
                    let first = data["firstName"] as? String ?? ""
                    let last  = data["lastName"]  as? String ?? ""

                    var name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                    if name.isEmpty {
                        // optional: fall back to email if you want something more helpful than "Unknown"
                        name = data["email"] as? String ?? "Unknown"
                    }

                    // cache it
                    self.userNameCache[ownerUID] = name

                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: indexPath) as? ClosetFeedCell {
                            visible.nameLabel.text = name
                        }
                    }
                }
            }
        }


        // title
        cell.titleLabel.text = item["name"] as? String ?? ""

        // Load the item image if stored as a URL string
        if let urlString = item["image"] as? String {
            let targetIndexPath = indexPath

            if urlString.hasPrefix("gs://") {
                // Firebase Storage path
                let ref = Storage.storage().reference(forURL: urlString)
                ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                    guard let data = data, error == nil,
                          let img = UIImage(data: data) else { return }

                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: targetIndexPath) as? ClosetFeedCell {
                            visible.itemImage.image = img
                        }
                    }
                }
            } else if let url = URL(string: urlString) {
                // Regular HTTPS URL
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let img = UIImage(data: data) {
                        DispatchQueue.main.async {
                            if let visible = tableView.cellForRow(at: targetIndexPath) as? ClosetFeedCell {
                                visible.itemImage.image = img
                            }
                        }
                    }
                }.resume()
            }
        } else {
            cell.itemImage.image = nil
        }


        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200  
    }

}
