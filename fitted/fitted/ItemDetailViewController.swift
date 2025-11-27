//
//  ItemDetailViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/26/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class ItemDetailViewController: UIViewController {

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var brandLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var itemImage: UIImageView!
    @IBOutlet weak var requestButton: UIButton!
    
    var itemData: [String: Any]!
    var itemId: String!
    private let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        configureUI()
        updateRequestButtonUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        requestButton.layer.cornerRadius = 12      // or requestButton.bounds.height / 2 for pill
        requestButton.clipsToBounds = true
    }

    
    private func configureUI() {
        guard let itemData = itemData else { return }
        
        // Basic fields
        titleLabel.text       = itemData["name"] as? String ?? ""
        brandLabel.text       = itemData["brand"] as? String ?? ""
        sizeLabel.text        = itemData["size"] as? String ?? ""
        descriptionLabel.text = itemData["description"] as? String ?? ""
        
        if let price = itemData["price"] as? NSNumber {
            priceLabel.text = "$\(price)"
        } else {
            priceLabel.text = ""
        }
        
        // Item image
        if let imagePath = itemData["image"] as? String {
            loadImage(from: imagePath) { [weak self] image in
                DispatchQueue.main.async {
                    self?.itemImage.image = image
                }
            }
        }
        
        // Owner info: name + profile picture
        if let ownerUID = itemData["owner"] as? String {
            db.collection("users").document(ownerUID).getDocument { [weak self] snap, _ in
                guard let self = self else { return }
                let data = snap?.data() ?? [:]
                
                let first = data["firstName"] as? String ?? ""
                let last  = data["lastName"]  as? String ?? ""
                var name  = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                if name.isEmpty {
                    name = data["email"] as? String ?? "Unknown"
                }
                
                DispatchQueue.main.async {
                    self.nameLabel.text = name
                }
                
                if let profilePath = data["profilePicture"] as? String {
                    self.loadImage(from: profilePath) { [weak self] img in
                        DispatchQueue.main.async {
                            self?.profileImage.image = img
                        }
                    }
                }
            }
        }
    }
    
    // handles both gs:// and https://
    private func loadImage(from path: String, completion: @escaping (UIImage?) -> Void) {
        if path.hasPrefix("gs://") {
            // Firebase Storage path
            let ref = Storage.storage().reference(forURL: path)
            ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                guard let data = data, error == nil else {
                    completion(nil)
                    return
                }
                completion(UIImage(data: data))
            }
        } else if let url = URL(string: path) {
            // Regular HTTPS URL
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data else {
                    completion(nil)
                    return
                }
                completion(UIImage(data: data))
            }.resume()
        } else {
            completion(nil)
        }
    }
    
    @IBAction func requestButtonPressed(_ sender: Any) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let ownerId = itemData["owner"] as? String else { return }
        guard let itemId = itemId else { return }

        // Don’t allow requesting your own item
        if currentUid == ownerId { return }

        let requestsRef = db.collection("requests")
        let reqRef = requestsRef.document()

        let reqData: [String: Any] = [
            "itemId": itemId,
            "ownerId": ownerId,
            "requesterId": currentUid,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]

        let requesterUserRef = db.collection("users").document(currentUid)
        let ownerUserRef     = db.collection("users").document(ownerId)
        let itemRef          = db.collection("closet_items").document(itemId)

        let batch = db.batch()

        // 1) new request doc
        batch.setData(reqData, forDocument: reqRef)

        // 2) add to outgoing / incoming arrays
        batch.setData(
            ["outgoingRequests": FieldValue.arrayUnion([reqRef.documentID])],
            forDocument: requesterUserRef,
            merge: true
        )
        batch.setData(
            ["incomingRequests": FieldValue.arrayUnion([reqRef.documentID])],
            forDocument: ownerUserRef,
            merge: true
        )

        // 3) optionally mark item status + requestedBy
        batch.updateData(
            ["status": "pending",
             "requestedBy": currentUid],
            forDocument: itemRef
        )

        batch.commit { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("Failed to create request: \(error.localizedDescription)")
                return
            }

            // Update local model + button state after success
            self.itemData["status"] = "pending"
            self.itemData["requestedBy"] = currentUid
            self.updateRequestButtonUI()

            // Show confirmation
            let ac = UIAlertController(
                title: "Request Sent",
                message: "Your request has been sent to the owner.",
                preferredStyle: .alert
            )
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(ac, animated: true)
        }
    }
    
    func updateRequestButtonUI() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let status = itemData["status"] as? String ?? "available"
        let requestedBy = itemData["requestedBy"] as? String
        let ownerId = itemData["owner"] as? String

        // If user owns the item
        if currentUid == ownerId {
            requestButton.setTitle("You Own This", for: .normal)
            requestButton.backgroundColor = .lightGray
            requestButton.isEnabled = false
            return
        }

        // AVAILABLE
        if status == "available" {
            requestButton.setTitle("Request", for: .normal)
            self.requestButton.backgroundColor = UIColor(named: "SecondaryPink")
            requestButton.isEnabled = true
            return
        }

        // PENDING — requested by current user
        if status == "pending", requestedBy == currentUid {
            requestButton.setTitle("Requested", for: .normal)
            self.requestButton.backgroundColor = UIColor(named: "AccentColorGreen")
            requestButton.isEnabled = false
            return
        }

        // PENDING — requested by someone else
//        if status == "pending", requestedBy != currentUid {
//            requestButton.setTitle("Pending", for: .normal)
//            requestButton.backgroundColor = UIColor.lightGray
//            requestButton.isEnabled = false
//            return
//        }

        // NOT AVAILABLE (optional future state)
//        if status == "unavailable" {
//            requestButton.setTitle("Unavailable", for: .normal)
//            requestButton.backgroundColor = UIColor.darkGray
//            requestButton.isEnabled = false
//            return
//        }
        
        requestButton.layer.cornerRadius = 12
        requestButton.layer.masksToBounds = true
    }



}
