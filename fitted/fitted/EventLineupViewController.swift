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
    let id: String
    let title: String
    let description: String
    let location: String
    let date: Date
    let dateText: String
    let imageURL: String?
}

class EventLineupViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    

    @IBOutlet weak var tableView: UITableView!
    
    var events: [Event] = []
    private let db = Firestore.firestore()
    var groupId: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        fetchEvents()
        navigationController?.navigationBar.tintColor = UIColor(named: "MainText")
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchEvents()
        tableView.reloadData()
    }

    
    private func fetchEvents() {
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

            let eventsCollection = self.db.collection("events")
            var loadedEvents: [Event] = []
            let group = DispatchGroup()

            // Start of "today" in the user’s current calendar/time zone
            let today = Calendar.current.startOfDay(for: Date())

            for id in eventIDs {
                group.enter()
                eventsCollection.document(id).getDocument { docSnapshot, error in
                    defer { group.leave() }

                    guard let doc = docSnapshot, doc.exists else { return }
                    let d = doc.data() ?? [:]

                    // time is a Firestore Timestamp
                    guard let timestamp = d["time"] as? Timestamp else { return }
                    let eventDate = timestamp.dateValue()

                    // Only keep events that are today or in the future
                    guard eventDate >= today else { return }

                    let event = Event(
                        id: doc.documentID,
                        title: d["event_name"] as? String ?? "",
                        description: d["description"] as? String ?? "",
                        location: d["location"] as? String ?? "",
                        date: eventDate,
                        dateText: self.formatDate(eventDate),
                        imageURL: d["image"] as? String
                    )
                    loadedEvents.append(event)
                }
            }

            group.notify(queue: .main) {
                self.events = loadedEvents.sorted { $0.date < $1.date }
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

    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedEvent = events[indexPath.row]

        let sb = UIStoryboard(name: "Main", bundle: nil)
        if let vc = sb.instantiateViewController(withIdentifier: "ClosetFeedViewController") as? ClosetFeedViewController {
            vc.eventId = selectedEvent.id          // pass the event’s document ID
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            guard segue.identifier == "createEventSegue" else { return }

            if let createVC = segue.destination as? CreateEventViewController {
                createVC.groupId = groupId
            }
        }

}
