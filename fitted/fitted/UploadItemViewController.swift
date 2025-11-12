//
//  UploadItemViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class UploadItemViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var addItemButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var uploadImageButton: UIButton!
    @IBOutlet weak var descriptionText: UITextView!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var brandField: UITextField!
    @IBOutlet weak var clothingTypeField: UITextField!
    @IBOutlet weak var colorField: UITextField!
    @IBOutlet weak var sizeField: UITextField!
    @IBOutlet weak var rentalPriceField: UITextField!
    
    private let db = Firestore.firestore()
    private let itemsCollection = "closet_items"

    // --- Picker-only additions ---
    private enum PickerKind { case size, type, color }
    private let sizeOptions  = ["XS", "S", "M", "L", "XL"]
    private let typeOptions  = ["dress", "top", "bottom", "skirt", "set"]
    private let colorOptions = ["black", "white", "red", "pink", "blue", "green", "yellow", "orange", "brown", "gray", "beige"]

    private let picker = UIPickerView()
    private var currentPickerKind: PickerKind?
    
    private var selectedImageData: Data?

    override func viewDidLoad() {
        super.viewDidLoad()

        // picker wiring
        picker.delegate = self
        picker.dataSource = self

        // attach picker to these fields
        sizeField.inputView = picker
        clothingTypeField.inputView = picker
        colorField.inputView = picker

        sizeField.delegate = self
        clothingTypeField.delegate = self
        colorField.delegate = self

        // toolbar with Done
        let tb = UIToolbar()
        tb.sizeToFit()
        tb.items = [UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(pickerDone))]
        sizeField.inputAccessoryView = tb
        clothingTypeField.inputAccessoryView = tb
        colorField.inputAccessoryView = tb
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField === sizeField      { currentPickerKind = .size }
        else if textField === clothingTypeField { currentPickerKind = .type }
        else if textField === colorField { currentPickerKind = .color }

        picker.reloadAllComponents()

        // Preselect current value if present
        let options: [String]
        let currentText = textField.text ?? ""
        switch currentPickerKind {
        case .size:  options = sizeOptions
        case .type:  options = typeOptions
        case .color: options = colorOptions
        case .none:  options = []
        }
        if let idx = options.firstIndex(of: currentText) {
            picker.selectRow(idx, inComponent: 0, animated: false)
        } else {
            picker.selectRow(0, inComponent: 0, animated: false)
        }
        return true
    }

    // MARK: - UIPickerViewDataSource / Delegate
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch currentPickerKind {
        case .size:  return sizeOptions.count
        case .type:  return typeOptions.count
        case .color: return colorOptions.count
        case .none:  return 0
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch currentPickerKind {
        case .size:  return sizeOptions[row]
        case .type:  return typeOptions[row]
        case .color: return colorOptions[row]
        case .none:  return nil
        }
    }

    @objc private func pickerDone() {
        let row = picker.selectedRow(inComponent: 0)
        switch currentPickerKind {
        case .size:
            sizeField.text = sizeOptions[row]
        case .type:
            clothingTypeField.text = typeOptions[row]
        case .color:
            colorField.text = colorOptions[row]
        case .none:
            break
        }
        view.endEditing(true)
    }

    // MARK: - Save exactly as before
    @IBAction func addButtonPressed(_ sender: Any) {
        guard let uid = Auth.auth().currentUser?.uid else { print("No signed-in user."); return }

        let name  = nameField.text ?? ""
        let brand = brandField.text ?? ""
        let priceNumber: NSNumber? = {
            if let t = rentalPriceField.text, let d = Double(t) { return NSNumber(value: d) }
            return nil
        }()
        let size   = sizeField.text ?? ""
        let color  = colorField.text ?? ""
        let ctype  = clothingTypeField.text ?? ""
        let desc   = descriptionText.text ?? ""

        var itemData: [String: Any] = [
            "available": true,
            "brand": brand,
            "clothing_type": ctype,
            "color": color,
            "description": desc,
            "name": name,
            "owner": uid,
            "size": size
        ]
        if let priceNumber = priceNumber { itemData["price"] = priceNumber }

               // If an image was picked, upload to Storage first, then save document with "image" URL
               if let data = selectedImageData {
                   let imageRef = Storage.storage()
                       .reference()
                       .child("closet_images/\(uid)/\(UUID().uuidString).jpg")

                   let metadata = StorageMetadata()
                   metadata.contentType = "image/jpeg"

                   imageRef.putData(data, metadata: metadata) { [weak self] _, err in
                       guard let self = self else { return }
                       if let err = err { print("Image upload failed: \(err.localizedDescription)"); self.saveItem(itemData: itemData, ownerUid: uid, imageURL: nil); return }

                       imageRef.downloadURL { url, urlErr in
                           if let urlErr = urlErr {
                               print("Failed to fetch download URL: \(urlErr.localizedDescription)")
                               self.saveItem(itemData: itemData, ownerUid: uid, imageURL: nil)
                               return
                           }
                           self.saveItem(itemData: itemData, ownerUid: uid, imageURL: url?.absoluteString)
                       }
                   }
               } else {
                   // No image selected; save immediately
                   saveItem(itemData: itemData, ownerUid: uid, imageURL: nil)
               }
    }
    
    // Save doc, update my_closet, show confirmation, and pop back
    private func saveItem(itemData: [String: Any], ownerUid uid: String, imageURL: String?) {
        var toSave = itemData
        if let imageURL = imageURL {
            toSave["image"] = imageURL          // store the download URL under "image"
        }

        var newDocRef: DocumentReference?
        newDocRef = db.collection(itemsCollection).addDocument(data: toSave) { [weak self] error in
            guard let self = self else { return }
            if let error = error { print("Failed to add item: \(error.localizedDescription)"); return }
            guard let itemId = newDocRef?.documentID else { return }

            // Add to user's my_closet (creates field/doc if missing)
            self.db.collection("users").document(uid)
                .setData(["my_closet": FieldValue.arrayUnion([itemId])], merge: true) { err in
                    if let err = err { print("Failed to update my_closet: \(err.localizedDescription)") }
                    // Confirmation + pop back
                    DispatchQueue.main.async {
                        let ac = UIAlertController(title: "Item Added",
                                                   message: "Your item has been added to My Closet.",
                                                   preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            self.navigationController?.popViewController(animated: true)
                        })
                        self.present(ac, animated: true)
                    }
                }
        }
    }


    @IBAction func uploadButtonPressed(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self       // ← Works once conformance is correct
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    // Handle the selected image
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        let img = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)

        print("imagePickerController called, image is nil? \(img == nil)")  // <- debug log

        guard let finalImage = img else {
            picker.dismiss(animated: true)
            return
        }

        DispatchQueue.main.async {
            self.imageView.image = finalImage           // ✅ this updates the UI
            self.selectedImageData = finalImage.jpegData(compressionQuality: 0.9)
        }

        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
