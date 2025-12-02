//
//  MyInquiriesViewController.swift
//  fitted
//
//  Created by Sujitha Seenivasan on 12/1/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct MyInquiry {
    let id: String
    var status: String
    let itemName: String
    let itemId: String
    let eventId: String
    let itemImageURL: String?
    let requesterId: String
    let requesterName: String?
    let groupName: String?
    let eventName: String?
    var requesterPhone: String?
}

class MyInquiriesViewController: UIViewController,
                                 UITableViewDataSource,
                                 UITableViewDelegate,
                                 MyInquiriesCellDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    private let db = Firestore.firestore()
    private var inquiries: [MyInquiry] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.tableFooterView = UIView()
        fetchIncomingRequests()
    }
    
    // MARK: - Firestore loading
    
    private func fetchIncomingRequests() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("requests")
            .whereField("ownerId", isEqualTo: uid)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error loading incoming requests: \(error)")
                    return
                }
                self.buildInquiries(from: snapshot?.documents ?? [])
            }
    }
    
    private func buildInquiries(from docs: [QueryDocumentSnapshot]) {
        let group = DispatchGroup()
        var built: [MyInquiry] = []
        
        for doc in docs {
            let data = doc.data()
            let reqId = doc.documentID
            
            let status       = data["status"] as? String ?? "pending"
            let itemId       = data["itemId"] as? String ?? ""
            let requesterId  = data["requesterId"] as? String ?? ""
            let groupId      = data["groupId"] as? String ?? ""
            let eventId      = data["eventId"] as? String ?? ""
            
            var itemName: String = ""
            var imageURL: String?
            
            var requesterName: String?
            var requesterPhone: String?
            
            var groupName: String?
            var eventName: String?
            
            let inner = DispatchGroup()
            
            // item
            if !itemId.isEmpty {
                inner.enter()
                db.collection("closet_items").document(itemId).getDocument { snap, _ in
                    if let d = snap?.data() {
                        itemName = d["name"] as? String ?? ""
                        imageURL = d["image"] as? String
                    }
                    inner.leave()
                }
            }
            
            // requester name + phone
            if !requesterId.isEmpty {
                inner.enter()
                db.collection("users").document(requesterId).getDocument { snap, _ in
                    if let u = snap?.data() {
                        let first = u["firstName"] as? String ?? ""
                        let last  = u["lastName"]  as? String ?? ""
                        let full  = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                        requesterName = full.isEmpty ? (u["username"] as? String ?? "Unknown") : full
                        requesterPhone = u["phoneNumber"] as? String
                    }
                    inner.leave()
                }
            }
            
            // event name
            if !eventId.isEmpty {
                inner.enter()
                db.collection("events").document(eventId).getDocument { snap, _ in
                    if let d = snap?.data() {
                        eventName = d["event_name"] as? String
                    }
                    inner.leave()
                }
            }
            
            // group name
            if !groupId.isEmpty {
                inner.enter()
                db.collection("groups").document(groupId).getDocument { snap, _ in
                    if let d = snap?.data() {
                        groupName = d["group_name"] as? String
                    }
                    inner.leave()
                }
            }
            
            group.enter()
            inner.notify(queue: .main) {
                let inquiry = MyInquiry(
                    id: reqId,
                    status: status,
                    itemName: itemName,
                    itemId: itemId,
                    eventId: eventId,
                    itemImageURL: imageURL,
                    requesterId: requesterId,
                    requesterName: requesterName,
                    groupName: groupName,
                    eventName: eventName,
                    requesterPhone: requesterPhone
                )
                built.append(inquiry)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.inquiries = built
            self.tableView.reloadData()
        }
    }
    
    // MARK: - TableView
    
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return inquiries.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "MyInquiryCell",
            for: indexPath
        ) as! MyInquiriesTableViewCell
        
        let inquiry = inquiries[indexPath.row]
        
        cell.delegate = self
        
        cell.titleLabel.text       = inquiry.itemName
        cell.requestedByLabel.text = inquiry.requesterName ?? "Unknown"
        
        if let g = inquiry.groupName {
            cell.groupLabel.text = "Group: \(g)"
        } else {
            cell.groupLabel.text = nil
        }
        
        if let e = inquiry.eventName {
            cell.eventLabel.text = "Event: \(e)"
        } else {
            cell.eventLabel.text = nil
        }
        
        configureStatusUI(for: cell, inquiry: inquiry)
        
        // image
        cell.itemImageView.image = nil
        if let urlString = inquiry.itemImageURL {
            let targetIndexPath = indexPath
            
            if urlString.hasPrefix("gs://") {
                let ref = Storage.storage().reference(forURL: urlString)
                ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                    guard let data = data, error == nil,
                          let img = UIImage(data: data) else { return }
                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: targetIndexPath) as? MyInquiriesTableViewCell {
                            visible.itemImageView.image = img
                        }
                    }
                }
            } else if let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data = data, let img = UIImage(data: data) else { return }
                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: targetIndexPath) as? MyInquiriesTableViewCell {
                            visible.itemImageView.image = img
                        }
                    }
                }.resume()
            }
        }
        
        return cell
    }
    
    private func configureStatusUI(for cell: MyInquiriesTableViewCell,
                                   inquiry: MyInquiry) {
        let statusLower = inquiry.status.lowercased()
        
        if statusLower == "pending" {
            // show buttons, hide labels
            cell.approveButton.isHidden = false
            cell.denyButton.isHidden    = false
            cell.statusLabel.isHidden   = true
            cell.contactLabel.isHidden  = true
        } else {
            // hide buttons, show status label
            cell.approveButton.isHidden = true
            cell.denyButton.isHidden    = true
            
            cell.statusLabel.isHidden   = false
            cell.statusLabel.text       = inquiry.status.capitalized
            
            if statusLower == "approved",
               let phone = inquiry.requesterPhone,
               !phone.isEmpty {
                cell.contactLabel.isHidden = false
                cell.contactLabel.text = "Contact: \(phone)"
            } else {
                cell.contactLabel.isHidden = true
                cell.contactLabel.text = nil
            }
        }
    }
    
    // MARK: - Cell delegate
    
    // MARK: - Cell delegate
    
    func inquiryCellDidTapApprove(_ cell: MyInquiriesTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let inquiry = inquiries[indexPath.row]
        attemptApprove(inquiry: inquiry, at: indexPath)
    }
    
    func inquiryCellDidTapDeny(_ cell: MyInquiriesTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        let inquiry = inquiries[indexPath.row]
        updateRequestStatus(for: inquiry, newStatus: "denied", at: indexPath)
    }
    
    // MARK: - Approve logic with protection
    
    private func attemptApprove(inquiry: MyInquiry, at indexPath: IndexPath) {
        // If we don't have an item id, just approve normally
        guard !inquiry.itemId.isEmpty else {
            updateRequestStatus(for: inquiry, newStatus: "approved", at: indexPath)
            return
        }
        
        // Check if this item is already approved for THIS event
        db.collection("requests")
            .whereField("itemId", isEqualTo: inquiry.itemId)
            .whereField("eventId", isEqualTo: inquiry.eventId)   // eventId is a plain String
            .whereField("status", isEqualTo: "approved")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error checking existing approvals: \(error)")
                    // (optional) show a generic error alert here
                    return
                }
                
                let docs = snapshot?.documents ?? []
                
                if !docs.isEmpty {
                    // There is already an approved request for this item & event
                    let alert = UIAlertController(
                        title: "Already Approved",
                        message: "This item is already approved for someone for this event. You can only approve it for one person per event.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    return
                }
                
                // Safe to approve
                self.updateRequestStatus(for: inquiry, newStatus: "approved", at: indexPath)
            }
    }
    
    // MARK: - Status update helper
    
    private func updateRequestStatus(for inquiry: MyInquiry,
                                     newStatus: String,
                                     at indexPath: IndexPath) {
        // Optimistic UI update
        inquiries[indexPath.row].status = newStatus
        tableView.reloadRows(at: [indexPath], with: .automatic)
        
        db.collection("requests").document(inquiry.id)
            .updateData(["status": newStatus]) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Failed to update status: \(error)")
                    // (Optional) revert UI or show error alert
                    return
                }
                
                // If you want to ensure we have the latest phone number on approve:
                if newStatus == "approved" {
                    self.db.collection("users").document(inquiry.requesterId)
                        .getDocument { snap, _ in
                            if let data = snap?.data() {
                                let phone = data["phoneNumber"] as? String
                                self.inquiries[indexPath.row].requesterPhone = phone
                            }
                            DispatchQueue.main.async {
                                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                            }
                        }
                }
            }
    }
}

