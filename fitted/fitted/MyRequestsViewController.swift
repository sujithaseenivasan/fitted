//
//  MyRequestsViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/27/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct MyRequest {
    let id: String
    let status: String
    let itemName: String
    let itemImageURL: String?
    let ownerName: String?
    let groupId: String?
    let eventId: String?
}

class MyRequestsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    private let db = Firestore.firestore()
    private var requests: [MyRequest] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        fetchOutgoingRequests()
    }
    
    private func fetchOutgoingRequests() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // 1) Get this user's outgoingRequests array
        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
            guard let self = self else { return }
            let data = snap?.data() ?? [:]
            let requestIds = data["outgoingRequests"] as? [String] ?? []

            guard !requestIds.isEmpty else {
                self.requests = []
                self.tableView.reloadData()
                return
            }

            self.loadRequests(requestIds: requestIds)
        }
    }

    private func loadRequests(requestIds: [String]) {
        let group = DispatchGroup()
        var built: [MyRequest] = []

        for reqId in requestIds {
            group.enter()

            db.collection("requests").document(reqId).getDocument { [weak self] reqSnap, _ in
                guard let self = self else { group.leave(); return }

                guard let reqData = reqSnap?.data() else {
                    group.leave()
                    return
                }

                let status = reqData["status"] as? String ?? "pending"
                let itemId = reqData["itemId"] as? String ?? ""
                let ownerId = reqData["ownerId"] as? String
                
                let groupId = reqData["groupId"] as? String
                let eventId = reqData["eventId"] as? String

                var itemName: String = ""
                var imageURL: String?
                var ownerName: String?

                let inner = DispatchGroup()

                // Fetch item info
                if !itemId.isEmpty {
                    inner.enter()
                    self.db.collection("closet_items").document(itemId).getDocument { itemSnap, _ in
                        if let itemData = itemSnap?.data() {
                            itemName = itemData["name"] as? String ?? ""
                            imageURL = itemData["image"] as? String
                        }
                        inner.leave()
                    }
                }

                // Fetch owner name
                if let ownerId = ownerId {
                    inner.enter()
                    self.db.collection("users").document(ownerId).getDocument { userSnap, _ in
                        if let userData = userSnap?.data() {
                            let first = userData["firstName"] as? String ?? ""
                            let last  = userData["lastName"]  as? String ?? ""
                            let full = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                            ownerName = full.isEmpty ? (userData["username"] as? String ?? "Unknown") : full
                        }
                        inner.leave()
                    }
                }

                inner.notify(queue: .main) {
                    let req = MyRequest(
                        id: reqId,
                        status: status,
                        itemName: itemName,
                        itemImageURL: imageURL,
                        ownerName: ownerName,
                        groupId: groupId,
                        eventId: eventId
                    )
                    built.append(req)
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            self.requests = built
            self.tableView.reloadData()
        }
    }

    // MARK: - TableView Data Source

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyRequestCell",
                                                 for: indexPath) as! MyRequestsTableViewCell

        let req = requests[indexPath.row]

        // Item title
        cell.titleLabel.text = req.itemName

        // Status (e.g., "pending", "approved", "rejected")
        cell.statusLabel.text = req.status.capitalized

        // Show who owns the item
        cell.requestedByLabel.text = req.ownerName ?? "Unknown"

        // For now we don't have group / event info in the request doc,
        // so we leave these empty.
        cell.groupLabel.text = req.groupId
        cell.eventLabel.text = req.eventId

        // Clear old image
        cell.itemImage.image = nil

        // Load item image if we have a URL
        if let urlString = req.itemImageURL {
            let targetIndexPath = indexPath

            if urlString.hasPrefix("gs://") {
                // Firebase Storage path
                let ref = Storage.storage().reference(forURL: urlString)
                ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                    guard let data = data, error == nil,
                          let img = UIImage(data: data) else { return }

                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: targetIndexPath) as? MyRequestsTableViewCell {
                            visible.itemImage.image = img
                        }
                    }
                }
            } else if let url = URL(string: urlString) {
                // HTTPS URL
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data = data, let img = UIImage(data: data) else { return }
                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: targetIndexPath) as? MyRequestsTableViewCell {
                            visible.itemImage.image = img
                        }
                    }
                }.resume()
            }
        }

        return cell
    }

}
