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
    let itemId: String
    let ownerId: String?
    let itemName: String
    let itemImageURL: String?
    let ownerName: String?
    let groupId: String?
    let eventId: String?
    let groupName: String?
    let eventName: String?
    let eventDate: Date
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        
        let today = Calendar.current.startOfDay(for: Date())

        for reqId in requestIds {
            group.enter()

            db.collection("requests").document(reqId).getDocument { [weak self] reqSnap, _ in
                guard let self = self else { group.leave(); return }

                guard let reqData = reqSnap?.data() else {
                    group.leave()
                    return
                }

                let status  = reqData["status"] as? String ?? "pending"
                let itemId  = reqData["itemId"] as? String ?? ""
                let ownerId = reqData["ownerId"] as? String

                let groupId = reqData["groupId"] as? String ?? ""
                let eventId = reqData["eventId"] as? String ?? ""

                var itemName: String = ""
                var imageURL: String?
                var ownerName: String?

                var groupName: String?
                var eventName: String?
                var eventDate: Date?

                let inner = DispatchGroup()

                // item
                if !itemId.isEmpty {
                    inner.enter()
                    self.db.collection("closet_items").document(itemId).getDocument { snap, _ in
                        if let d = snap?.data() {
                            itemName = d["name"] as? String ?? ""
                            imageURL = d["image"] as? String
                        }
                        inner.leave()
                    }
                }

                // owner name
                if let ownerId = ownerId, !ownerId.isEmpty {
                    inner.enter()
                    self.db.collection("users").document(ownerId).getDocument { snap, _ in
                        if let u = snap?.data() {
                            let first = u["firstName"] as? String ?? ""
                            let last  = u["lastName"]  as? String ?? ""
                            let full  = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                            ownerName = full.isEmpty ? (u["username"] as? String ?? "Unknown") : full
                        }
                        inner.leave()
                    }
                }

                // event name (note field: "event_name", like in MyInquiries)
                if !eventId.isEmpty {
                    inner.enter()
                    self.db.collection("events").document(eventId).getDocument { snap, _ in
                        if let d = snap?.data() {
                            eventName = d["event_name"] as? String
                            if let ts = d["time"] as? Timestamp {
                                eventDate = ts.dateValue()
                            }
                        }
                        inner.leave()
                    }
                }

                // group name (note field: "group_name", like in MyInquiries)
                if !groupId.isEmpty {
                    inner.enter()
                    self.db.collection("groups").document(groupId).getDocument { snap, _ in
                        if let d = snap?.data() {
                            groupName = d["group_name"] as? String
                        }
                        inner.leave()
                    }
                }

                inner.notify(queue: .main) {
                    print("Request \(reqId) has eventId=\(eventId), groupId=\(groupId), eventName=\(eventName ?? "nil"), groupName=\(groupName ?? "nil")")

                    // Only include requests where we have an event
                    // AND the event is today or in the future
                    if let eventDate = eventDate, eventDate >= today {
                        let req = MyRequest(
                            id: reqId,
                            status: status,
                            itemId: itemId,
                            ownerId: ownerId,
                            itemName: itemName,
                            itemImageURL: imageURL,
                            ownerName: ownerName,
                            groupId: groupId.isEmpty ? nil : groupId,
                            eventId: eventId.isEmpty ? nil : eventId,
                            groupName: groupName,
                            eventName: eventName,
                            eventDate: eventDate
                        )
                        built.append(req)
                    }

                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            // sort by upcoming event date
            self.requests = built.sorted { $0.eventDate < $1.eventDate }
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
        
        cell.delegate = self

        // Item title
        cell.titleLabel.text = req.itemName

        // Status (e.g., "pending", "approved", "rejected")
        cell.statusLabel.text = req.status.capitalized

        // Show who owns the item
        cell.requestedByLabel.text = req.ownerName ?? "Unknown"

        // For now we don't have group / event info in the request doc,
        // so we leave these empty.
    

        if let e = req.eventName {
            cell.eventLabel.text = "Event: \(e)"
        } else {
            cell.eventLabel.text = nil
        }

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
    
    private func cancelRequest(_ request: MyRequest, at indexPath: IndexPath) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let batch = db.batch()

        let requesterRef = db.collection("users").document(currentUid)
        let requestRef   = db.collection("requests").document(request.id)

        // Remove from outgoingRequests for current user
        batch.updateData([
            "outgoingRequests": FieldValue.arrayRemove([request.id])
        ], forDocument: requesterRef)

        // Remove from incomingRequests / newRequests for owner
        if let ownerId = request.ownerId {
            let ownerRef = db.collection("users").document(ownerId)
            batch.updateData([
                "incomingRequests": FieldValue.arrayRemove([request.id]),
                "newRequests": FieldValue.arrayRemove([request.id])
            ], forDocument: ownerRef)
        }

        // Option 1: delete the request document entirely
        batch.deleteDocument(requestRef)

        // Optionally: reset the item status to available
        if !request.itemId.isEmpty {
            let itemRef = db.collection("closet_items").document(request.itemId)
            batch.updateData([
                "status": "available",
                "requestedBy": FieldValue.delete()
            ], forDocument: itemRef)
        }

        batch.commit { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("Failed to cancel request: \(error.localizedDescription)")
                // You could show an alert here if you want
                return
            }

            // Update local model + table
            self.requests.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

}

//Cell Delegate
extension MyRequestsViewController: MyRequestsTableViewCellDelegate {
    func myRequestsCellDidTapCancel(_ cell: MyRequestsTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let req = requests[indexPath.row]

        let ac = UIAlertController(
            title: "Cancel Request",
            message: "Are you sure you want to cancel your request for \"\(req.itemName)\"?",
            preferredStyle: .alert
        )

        ac.addAction(UIAlertAction(title: "Keep Request", style: .cancel, handler: nil))

        ac.addAction(UIAlertAction(title: "Cancel Request", style: .destructive, handler: { _ in
            self.cancelRequest(req, at: indexPath)
        }))

        present(ac, animated: true)
    }
}

