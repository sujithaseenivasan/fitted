//
//  UploadItemViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class UploadItemViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    

    @IBOutlet weak var addItemButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var uploadImageButton: UIButton!
    @IBOutlet weak var descriptionText: UITextView!
    @IBOutlet weak var sizeField: UITextField!
    @IBOutlet weak var rentalPriceField: UITextField!
    @IBOutlet weak var brandField: UITextField!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var clothingTypeField: UITextField!
    @IBOutlet weak var colorField: UITextField!
    
    private let db = Firestore.firestore()
    private let itemsCollection = "closet_items"
    
    private enum PickerKind { case size, type, color }
    private let sizeOptions  = ["XS", "S", "M", "L", "XL"]
    private let typeOptions  = ["dress", "top", "bottom", "skirt", "set"]
    private let colorOptions = ["black", "white", "red", "pink", "blue", "green", "yellow", "orange", "brown", "gray", "beige"]
    
    private let picker = UIPickerView()
    private var currentPickerKind: PickerKind?
    
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
        
        
    }
    
    // Write the item to Firestore; owner = current user UID.
    // Then append the created item docID to current user's my_closet
    @IBAction func addButtonPressed(_ sender: Any) {
        // current user
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No signed-in user.")
            return
        }
    }
    @IBAction func uploadButtonPressed(_ sender: Any) {
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        <#code#>
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        <#code#>
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
