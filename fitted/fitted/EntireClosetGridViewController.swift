//
//  EntireClosetGridViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

struct EntireClosetItem {
    let id: String
    let name: String
    let size: String?
    let type: String?
    let color: String?
    let price: Double?
    let imageURL: String?

    init?(id: String, dict: [String: Any]) {
        self.id = id
        self.name = dict["name"] as? String ?? ""

        self.size  = dict["size"] as? String
        self.type  = dict["clothing_type"] as? String
        self.color = dict["color"] as? String

        if let p = dict["price"] as? NSNumber {
            self.price = p.doubleValue
        } else if let p = dict["price"] as? Double {
            self.price = p
        } else if let s = dict["price"] as? String, let d = Double(s) {
            self.price = d
        } else {
            self.price = nil
        }

        self.imageURL = dict["image"] as? String
    }
}

enum PriceSort {
    case none
    case lowToHigh
    case highToLow
}

class EntireClosetGridViewController: UIViewController,
                                      UICollectionViewDataSource,
                                      UICollectionViewDelegateFlowLayout {

    // MARK: - Outlets

    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var filterBarContainer: UIView!

    // Filter buttons (add 4 buttons in storyboard and hook them up)
    @IBOutlet weak var sizeButton: UIButton!
    @IBOutlet weak var typeButton: UIButton!
    @IBOutlet weak var priceButton: UIButton!
    @IBOutlet weak var colorButton: UIButton!

    @IBOutlet weak var filterStackView: UIStackView!
    // MARK: - Data

    var eventId: String!               // set this before pushing VC

    private let db = Firestore.firestore()

    private var allItems: [EntireClosetItem] = []
    private var filteredItems: [EntireClosetItem] = []
    private var cachedItemWidth: CGFloat = 0

    // current filter selections
    private var selectedSize: String?
    private var selectedType: String?
    private var selectedColor: String?
    private var priceSort: PriceSort = .none

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = self
        collectionView.delegate   = self
        
        for subview in filterStackView.arrangedSubviews {
            subview.layer.borderWidth = 1
            subview.layer.borderColor = UIColor.black.cgColor
            subview.layer.cornerRadius = 0   // or some radius if you want
            subview.clipsToBounds = true
        }

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumInteritemSpacing = 8       // space between items in a row
            layout.minimumLineSpacing      = 20      // vertical space between rows
        }

        // some bottom padding so last row isn't under tab bar
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 80, right: 0)

        resetFilterButtonTitles()
        fetchEventItems()
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //addFilterBarLines()
    }


    // MARK: - Firestore fetch

    private func fetchEventItems() {
        guard let eventId = eventId else {
            print("No eventId set")
            return
        }

        let eventRef = db.collection("events").document(eventId)
        eventRef.getDocument { [weak self] snap, err in
            guard let self = self else { return }

            if let err = err {
                print("Error fetching event:", err.localizedDescription)
                return
            }

            let data = snap?.data() ?? [:]
            let itemIds = data["event_items"] as? [String] ?? []

            guard !itemIds.isEmpty else {
                self.allItems = []
                self.filteredItems = []
                self.collectionView.reloadData()
                return
            }

            self.fetchClosetItems(ids: itemIds)
        }
    }

    private func fetchClosetItems(ids: [String]) {
        var loaded: [EntireClosetItem] = []
        let group = DispatchGroup()

        let chunks: [[String]] = stride(from: 0, to: ids.count, by: 10).map {
            Array(ids[$0 ..< min($0 + 10, ids.count)])
        }

        for chunk in chunks {
            group.enter()
            db.collection("closet_items")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snap, err in
                    defer { group.leave() }

                    if let err = err {
                        print("Error fetching closet items chunk:", err.localizedDescription)
                        return
                    }

                    snap?.documents.forEach { doc in
                        if let item = EntireClosetItem(id: doc.documentID, dict: doc.data()) {
                            loaded.append(item)
                        }
                    }
                }
        }

        group.notify(queue: .main) {
            self.allItems = loaded.sorted { $0.name < $1.name }
            self.applyFilters()
        }
    }

    // MARK: - Filtering

    private func applyFilters() {
        var items = allItems

        if let s = selectedSize {
            items = items.filter { $0.size == s }
        }
        if let t = selectedType {
            items = items.filter { $0.type == t }
        }
        if let c = selectedColor {
            items = items.filter { $0.color == c }
        }

        switch priceSort {
        case .lowToHigh:
            items = items.sorted { ($0.price ?? .greatestFiniteMagnitude) <
                                   ($1.price ?? .greatestFiniteMagnitude) }
        case .highToLow:
            items = items.sorted { ($0.price ?? 0) > ($1.price ?? 0) }
        case .none:
            break
        }

        filteredItems = items
        collectionView.reloadData()
    }

    private func resetFilterButtonTitles() {
        sizeButton.setTitle("Size", for: .normal)
        typeButton.setTitle("Type", for: .normal)
        priceButton.setTitle("Price", for: .normal)
        colorButton.setTitle("Color", for: .normal)
    }
    
    func addFilterBarLines() {

        // remove old lines first (so they don’t duplicate on rotation)
        filterBarContainer.layer.sublayers?.removeAll(where: { $0.name == "filterLine" })

        let top = CALayer()
        top.name = "filterLine"
        top.backgroundColor = UIColor.black.cgColor
        top.frame = CGRect(x: 0, y: 0, width: filterBarContainer.bounds.width, height: 1)
        filterBarContainer.layer.addSublayer(top)

        let bottom = CALayer()
        bottom.name = "filterLine"
        bottom.backgroundColor = UIColor.black.cgColor
        bottom.frame = CGRect(x: 0, y: filterBarContainer.bounds.height - 1, width: filterBarContainer.bounds.width, height: 1)
        filterBarContainer.layer.addSublayer(bottom)

        // Vertical lines between buttons
        let buttonWidth = filterBarContainer.bounds.width / 4
        for i in 1..<4 {
            let line = CALayer()
            line.name = "filterLine"
            line.backgroundColor = UIColor.black.cgColor
            let x = CGFloat(i) * buttonWidth
            line.frame = CGRect(x: x, y: 0, width: 1, height: filterBarContainer.bounds.height)
            filterBarContainer.layer.addSublayer(line)
        }
    }


    // MARK: - Filter button actions

    @IBAction func sizeButtonTapped(_ sender: Any) {
        let sizes = Array(Set(allItems.compactMap { $0.size })).sorted()
        presentFilterSheet(title: "Size", options: sizes, current: selectedSize) { selected in
            self.selectedSize = selected
            self.sizeButton.setTitle(selected ?? "Size", for: .normal)
            self.applyFilters()
        }
    }

    @IBAction func typeButtonTapped(_ sender: Any) {
        let types = Array(Set(allItems.compactMap { $0.type })).sorted()
        presentFilterSheet(title: "Type", options: types, current: selectedType) { selected in
            self.selectedType = selected
            self.typeButton.setTitle(selected ?? "Type", for: .normal)
            self.applyFilters()
        }
    }

    @IBAction func colorButtonTapped(_ sender: Any) {
        let colors = Array(Set(allItems.compactMap { $0.color })).sorted()
        presentFilterSheet(title: "Color", options: colors, current: selectedColor) { selected in
            self.selectedColor = selected
            self.colorButton.setTitle(selected ?? "Color", for: .normal)
            self.applyFilters()
        }
    }

    @IBAction func priceButtonTapped(_ sender: Any) {
        let ac = UIAlertController(title: "Price", message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "None", style: .default) { _ in
            self.priceSort = .none
            self.priceButton.setTitle("Price", for: .normal)
            self.applyFilters()
        })
        ac.addAction(UIAlertAction(title: "Low → High", style: .default) { _ in
            self.priceSort = .lowToHigh
            self.priceButton.setTitle("Price ↑", for: .normal)
            self.applyFilters()
        })
        ac.addAction(UIAlertAction(title: "High → Low", style: .default) { _ in
            self.priceSort = .highToLow
            self.priceButton.setTitle("Price ↓", for: .normal)
            self.applyFilters()
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(ac, animated: true)
    }

    private func presentFilterSheet(title: String,
                                    options: [String],
                                    current: String?,
                                    completion: @escaping (String?) -> Void) {
        let ac = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

        for value in options {
            let checked = (value == current) ? " ✓" : ""
            ac.addAction(UIAlertAction(title: value + checked, style: .default) { _ in
                completion(value)
            })
        }

        ac.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            completion(nil)
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(ac, animated: true)
    }

    // MARK: - Collection view data source

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return filteredItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "EntireClosetCell",
                for: indexPath
            ) as? EntireClosetCell else {
                return UICollectionViewCell()
            }

            let item = filteredItems[indexPath.item]
            cell.titleLabel.text = item.name
            
            // IMPORTANT: update label width to match our layout math
            cell.cellWidth = cachedItemWidth

            cell.imageView.image = nil

        let targetIndexPath = indexPath

        if let urlString = item.imageURL {
            if urlString.hasPrefix("gs://") {
                let ref = Storage.storage().reference(forURL: urlString)
                ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                    guard let data = data, error == nil,
                          let img = UIImage(data: data) else { return }

                    DispatchQueue.main.async {
                        if let visible = collectionView.cellForItem(at: targetIndexPath) as? EntireClosetCell {
                            visible.imageView.image = img
                        }
                    }
                }
            } else if let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data = data, let img = UIImage(data: data) else { return }
                    DispatchQueue.main.async {
                        if let visible = collectionView.cellForItem(at: targetIndexPath) as? EntireClosetCell {
                            visible.imageView.image = img
                        }
                    }
                }.resume()
            }
        }

        return cell
    }


    // MARK: - Layout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        // slight padding like in Figma
        return UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let insets = self.collectionView(collectionView,
                                         layout: collectionViewLayout,
                                         insetForSectionAt: indexPath.section)

        let numberOfItemsPerRow: CGFloat = 3
        let interItemSpacing: CGFloat = 8

        let totalHorizontalSpacing = interItemSpacing * (numberOfItemsPerRow - 1)
        let availableWidth = collectionView.bounds.width
            - insets.left - insets.right
            - totalHorizontalSpacing

        let itemWidth = floor(availableWidth / numberOfItemsPerRow)
        cachedItemWidth = itemWidth            // <-- remember this

        let imageHeight = itemWidth
        let labelHeight: CGFloat = 44          // a bit taller for 2 lines
        let itemHeight = imageHeight + labelHeight + 16

        return CGSize(width: itemWidth, height: itemHeight)
    }


    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        let selectedItem = filteredItems[indexPath.item]

        // Fetch the full closet_items document so ItemDetailVC
        // gets all fields (description, brand, owner, etc.)
        db.collection("closet_items").document(selectedItem.id).getDocument { [weak self] snap, _ in
            guard
                let self = self,
                let data = snap?.data()
            else { return }

            DispatchQueue.main.async {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                guard let detailVC = storyboard.instantiateViewController(
                    withIdentifier: "ItemDetailViewController"
                ) as? ItemDetailViewController else { return }

                // pass the item dictionary to ItemDetailViewController
                detailVC.itemId = selectedItem.id
                detailVC.itemData = [
                    "name": selectedItem.name,
                    "size": selectedItem.size as Any,
                    "price": selectedItem.price as Any,
                    "color": selectedItem.color as Any,
                    "clothing_type": selectedItem.type as Any,
                    "imageURL": selectedItem.imageURL as Any
                ]
                
                detailVC.eventId = self.eventId
                detailVC.groupId

                self.navigationController?.pushViewController(detailVC, animated: true)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }


}
