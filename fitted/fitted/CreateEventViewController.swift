//
//  CreateEventViewController.swift
//  fitted
//
//  Created by Sujitha Seenivasan on 10/20/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

class CreateEventViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {


    @IBOutlet weak var eventNameField: UITextField!
    
    @IBOutlet weak var eventDateField: UITextField!
    
    @IBOutlet weak var eventTimeField: UITextField!
    
    @IBOutlet weak var eventLocationField: UITextField!
    
    @IBOutlet weak var eventDescriptionTextView: UITextView!
    
    @IBOutlet weak var eventPhotoImageView: UIImageView!
    
    var groupId: String!
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let datePicker = UIDatePicker()
    private let timePicker = UIDatePicker()

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupTextView()
        setupPickers()
        setupTapToDismissKeyboard()
    }
    
    private func setupTextView() {
            eventDescriptionTextView.layer.cornerRadius = 8
            eventDescriptionTextView.layer.borderWidth = 0.5
            eventDescriptionTextView.layer.borderColor = UIColor.separator.cgColor
        }
    private func setupTapToDismissKeyboard() {
            let tap = UITapGestureRecognizer(target: self, action: #selector(endEditing))
            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
        }
    
    @objc private func endEditing() { view.endEditing(true) }
    
    private func setupPickers() {
            // Date picker (date only)
            datePicker.datePickerMode = .date
            if #available(iOS 13.4, *) { datePicker.preferredDatePickerStyle = .wheels }
            eventDateField.inputView = datePicker

            // Time picker (time only)
            timePicker.datePickerMode = .time
            if #available(iOS 13.4, *) { timePicker.preferredDatePickerStyle = .wheels }
            eventTimeField.inputView = timePicker

            // Accessory toolbar with Done button (shared)
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(handlePickersDone))
            toolbar.setItems([done], animated: false)
            eventDateField.inputAccessoryView = toolbar
            eventTimeField.inputAccessoryView = toolbar

            // Initial display text
            updateDateFieldText()
            updateTimeFieldText()

            // Live updates while scrolling wheels
            datePicker.addTarget(self, action: #selector(updateDateFieldText), for: .valueChanged)
            timePicker.addTarget(self, action: #selector(updateTimeFieldText), for: .valueChanged)
        }

        @objc private func handlePickersDone() {
            updateDateFieldText()
            updateTimeFieldText()
            view.endEditing(true)
        }

        @objc private func updateDateFieldText() {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            eventDateField.text = df.string(from: datePicker.date)
        }

        @objc private func updateTimeFieldText() {
            let tf = DateFormatter()
            tf.dateStyle = .none
            tf.timeStyle = .short
            eventTimeField.text = tf.string(from: timePicker.date)
        }

        // Combine date-only + time-only into one Date
        private func combine(date: Date, time: Date) -> Date {
            let cal = Calendar.current
            let d = cal.dateComponents([.year, .month, .day], from: date)
            let t = cal.dateComponents([.hour, .minute, .second], from: time)
            var comps = DateComponents()
            comps.year = d.year
            comps.month = d.month
            comps.day = d.day
            comps.hour = t.hour
            comps.minute = t.minute
            comps.second = t.second
            return cal.date(from: comps) ?? date
        }

    
    @IBAction func uploadImageButtonPressed(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        DispatchQueue.main.async {
            self.present(picker, animated: true)
        }
    }

    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = (info[.editedImage] ?? info[ .originalImage]) as? UIImage
            eventPhotoImageView.image = image
            dismiss(animated: true)
        }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss(animated: true)
        }
    
    @IBAction func createEventButtonPressed(_ sender: Any) {
        guard let groupId = groupId, !groupId.isEmpty else {
            print("Missing groupID")
        return
    }
    guard let name = eventNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
        print("Missing Name", "Please enter an event name.")
        return
    }
    let location = eventLocationField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let description = eventDescriptionTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let when = combine(date: datePicker.date, time: timePicker.date)

        
    let eventRef = db.collection("events").document()
    let eventId = eventRef.documentID

    // Upload image if present, then write Firestore
    if let image = eventPhotoImageView.image, let jpeg = image.jpegData(compressionQuality: 0.85) {
        let path = "event_images/\(groupId)/\(eventId).jpg"
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(jpeg, metadata: metadata) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                print("Image upload error:", error.localizedDescription)
                return
            }
            storageRef.downloadURL { url, err in
                if let err = err {
                    print("Download URL error:", err.localizedDescription)
                }
                let imageURL = url?.absoluteString
                self.writeEventAndLinkToGroup(eventRef: eventRef,
                                              eventId: eventId,
                                              name: name,
                                              description: description,
                                              location: location,
                                              time: when,
                                              imageURL: imageURL)
            }
        }
    } else {
        // No image — just write Firestore
        writeEventAndLinkToGroup(eventRef: eventRef,
                                 eventId: eventId,
                                 name: name,
                                 description: description,
                                 location: location,
                                 time: when,
                                 imageURL: nil)
    }
}

private func writeEventAndLinkToGroup(eventRef: DocumentReference,
                                      eventId: String,
                                      name: String,
                                      description: String,
                                      location: String,
                                      time: Date,
                                      imageURL: String?) {
    // Build event document
    var eventData: [String: Any] = [
        "event_name": name,
        "description": description,
        "location": location,
        "time": Timestamp(date: time),
    ]
    if let imageURL = imageURL { eventData["image"] = imageURL }

    // 1) Write event doc
    eventRef.setData(eventData) { [weak self] error in
        guard let self = self else { return }
        if let error = error {
            print("Error creating event:", error.localizedDescription)
            return
        }

        // 2) Link event to group
        self.db.collection("groups").document(self.groupId).updateData([
            "events": FieldValue.arrayUnion([eventId])
        ]) { err in
            if let err = err {
                print("Error linking event to group:", err.localizedDescription)
                return
            }
            
            self.navigationController?.popViewController(animated: true)
        }
    }
}
    
}
