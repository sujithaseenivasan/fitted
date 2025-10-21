//
//  EventLineupViewController.swift
//  fitted
//
//  Created by Sarah Neville on 10/20/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

struct Event {
    let title: String
    let description: String
    let location: String
    let dateText: String
    let imageURL: String?
}

class EventLineupViewController: UIViewController, UITableViewDataSource {
    

    @IBOutlet weak var tableView: UITableView!
    
    var events: [Event] = []
    private let db = Firestore.firestore()
    var groupId: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        fetchEvents()
        navigationController?.navigationBar.tintColor = UIColor(named: "MainText")
        
    }
    
    private func fetchEvents() {
        // Get the group document first
        db.collection("groups").document(groupId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching group:", error.localizedDescription)
                return
            }
            guard let data = snapshot?.data(),
                  let eventIDs = data["events"] as? [String],
                  !eventIDs.isEmpty else {
                print("No events found for this group.")
                return
            }

            // Fetch all the events using their IDs
            let eventsCollection = self.db.collection("events")
            var loadedEvents: [Event] = []
            let group = DispatchGroup() // to wait for all fetches to complete

            for id in eventIDs {
                group.enter()
                eventsCollection.document(id).getDocument { docSnapshot, error in
                    defer { group.leave() }
                    guard let doc = docSnapshot, doc.exists else { return }
                    let d = doc.data() ?? [:]
                    let event = Event(
                        title: d["event_name"] as? String ?? "",
                        description: d["description"] as? String ?? "",
                        location: d["location"] as? String ?? "",
                        dateText: self.formatDate(d["time"]),
                        imageURL: d["image"] as? String
                    )
                    loadedEvents.append(event)
                }
            }

            // When all documents are loaded, update the UI
            group.notify(queue: .main) {
                self.events = loadedEvents.sorted { $0.dateText < $1.dateText }
                self.tableView.reloadData()
            }
        }
    }

    
    private func loadImage(from storagePath: String, completion: @escaping (UIImage?) -> Void) {
        let ref = Storage.storage().reference(forURL: storagePath)
        ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
            guard let data = data, error == nil else { completion(nil); return }
            completion(UIImage(data: data))
        }
    }

    
    private func formatDate(_ value: Any?) -> String {
        if let timestamp = value as? Timestamp {
            let date = timestamp.dateValue()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return ""
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell",
                                                 for: indexPath) as! EventCell
        let event = events[indexPath.row]
        cell.eventTitle.text = event.title
        cell.eventDescription.text = event.description
        cell.eventLocation.text = event.location
        cell.eventDate.text = event.dateText

        // Clear any old image first
        cell.eventImage.image = nil

        // Load image from Firebase Storage if available
        if let path = event.imageURL {
            let targetIndexPath = indexPath
            let ref = Storage.storage().reference(forURL: path)
            ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
                guard let data = data, error == nil else {
                    print("Error loading image for event: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if let visible = tableView.cellForRow(at: targetIndexPath) as? EventCell {
                            visible.eventImage.image = image
                        }
                    }
                }
            }
        }

        return cell
    }

}
