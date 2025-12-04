//
//   
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
                if var data = snap?.data() {
                    data["id"] = snap!.documentID
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
                        name = data["email"] as? String ?? "Unknown"
                    }

                    // NEW: get profile picture URL from the *user* doc
                    let profileURL = data["profilePictureURL"] as? String

                    // cache the name if you want to keep that behavior
                    self.userNameCache[ownerUID] = name

                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: indexPath) as? ClosetFeedCell {
                            visible.nameLabel.text = name
                            // make sure ClosetFeedCell has this outlet
                            visible.profileImage.setImage(from: profileURL,
                                                          placeholder: UIImage(named: "DefaultAvatar"))
                        }
                    }
                }
            }
        }



        // title
        cell.titleLabel.text = item["name"] as? String ?? ""
        
        cell.itemImage.setImage(from: item["image"] as? String)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200  
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        let sb = UIStoryboard(name: "Main", bundle: nil)
        if let detailVC = sb.instantiateViewController(withIdentifier: "ItemDetailViewController") as? ItemDetailViewController {
            detailVC.itemData = item
            detailVC.itemId = item["id"] as? String
            
            detailVC.eventId = self.eventId                  // Always available here
            //detailVC.groupId = item["groupId"] as? String    // !dont think i have this field?
            
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
}

extension UIImageView {
    func setImage(from urlString: String?, placeholder: UIImage? = nil) {
        self.image = placeholder

        guard let urlString = urlString else { return }

        // Firebase Storage path
        if urlString.hasPrefix("gs://") {
            let ref = Storage.storage().reference(forURL: urlString)
            ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                guard let data = data, error == nil,
                      let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { self.image = img }
            }
            return
        }

        // Regular https URL
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async { self.image = img }
            }
        }.resume()
    }
}

