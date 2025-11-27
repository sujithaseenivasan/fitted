//
//  ItemDetailViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/26/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

class ItemDetailViewController: UIViewController {

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var brandLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var itemImage: UIImageView!
    
    var itemData: [String: Any]!
    private let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        configureUI()
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
    }


}
