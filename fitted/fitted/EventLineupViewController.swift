//
//  EventLineupViewController.swift
//  fitted
//
//  Created by Sarah Neville on 10/20/25.
//

import UIKit
import FirebaseFirestore

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
        
    }
    
    private func fetchEvents() {
        db.collection("groups")
          .document(groupId)
          .collection("events")
          .order(by: "time", descending: false)
          .getDocuments { [weak self] snapshot, _ in
              guard let self = self, let docs = snapshot?.documents else { return }
              
              self.events = docs.compactMap { doc in
                  let d = doc.data()
                  // Map your Firestore fields into the Event struct
                  return Event(
                    title: d["event_name"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    location: d["location"] as? String ?? "",
                    dateText: self.formatDate(d["time"]),
                    imageURL: d["image"] as? String
                  )
              }
              
              self.tableView.reloadData()
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

        cell.eventImage.image = nil
        if let urlString = event.imageURL, let url = URL(string: urlString) {
            let targetIndexPath = indexPath
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    if let visible = tableView.cellForRow(at: targetIndexPath) as? EventCell {
                        visible.eventImage.image = img
                    }
                }
            }.resume()
        }

        return cell
    }

    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
