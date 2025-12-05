//
//  CreateAccountViewController.swift
//  fitted
//
//  Created by Sujitha Seenivasan on 10/8/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreateAccountViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var createAccountTextLabel: UILabel!
    
    @IBOutlet weak var newToFittedTextLabel: UILabel!
    
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var phoneNumberField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var reenterPasswordField: UITextField!
    
    @IBOutlet weak var alreadyHaveAccountButton: UIButton!
    @IBOutlet weak var createAccountButton: UIButton!
    @IBOutlet weak var errorLabel: UILabel!

    let segueIdentifier = "homeSegue2"
    private var didSwapRoot = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.errorLabel.text = ""
//        createAccountTextLabel.font = UIFont(name: "Manjari-Regular", size: 32)
//        newToFittedTextLabel.font = UIFont(name: "Manjari-Regular", size: 20)
//        firstNameField.font = UIFont(name: "Manjari-Regular", size: 16)
//        lastNameField.font = UIFont(name: "Manjari-Regular", size: 16)
//        emailField.font = UIFont(name: "Manjari-Regular", size: 16)
//        phoneNumberField.font = UIFont(name: "Manjari-Regular", size: 16)
//        passwordField.font = UIFont(name: "Manjari-Regular", size: 16)
//        reenterPasswordField.font = UIFont(name: "Manjari-Regular", size: 16)
//        alreadyHaveAccountButton.titleLabel?.font = UIFont(name: "Manjari-Regular", size: 16)
//        createAccountButton.titleLabel?.font = UIFont(name: "Manjari-Regular", size: 18)
//        errorLabel.font = UIFont(name: "Manjari-Regular", size: 16)
        
        for field in [firstNameField, lastNameField, emailField, phoneNumberField, passwordField, reenterPasswordField] {
            field?.delegate = self
        }
        
        self.passwordField.isSecureTextEntry = true
        self.reenterPasswordField.isSecureTextEntry = true
        
        // Listener to check if a user has logged in and initiate segue
        Auth.auth().addStateDidChangeListener() { [weak self] _, user in
            guard let self = self, user != nil, !self.didSwapRoot else { return }
            self.didSwapRoot = true
            self.clearFields()
            DispatchQueue.main.async { self.switchToMainApp() }
        }
    }
    
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        guard let email = emailField.text,
              let password = passwordField.text else { return }
        let tempFirstName = self.firstNameField.text ?? ""
        let tempLastName = self.lastNameField.text ?? ""
        let tempPhoneNumber = self.phoneNumberField.text ?? ""
        
        if reenterPasswordField.text != passwordField.text {
            self.errorLabel.text = "Passwords do not match."
        } else {
            Auth.auth().createUser(withEmail: email, password: password) { (authResult, error) in
                if let error = error as NSError? {
                    self.errorLabel.text = "\(error.localizedDescription)"
                } else if let user = authResult?.user {
                    self.errorLabel.text = ""
        
                    // Save additional user info to Firestore
                    Firestore.firestore().collection("users").document(user.uid).setData([
                        "email": email,
                        "firstName": tempFirstName,
                        "lastName": tempLastName,
                        "phoneNumber": tempPhoneNumber,
                        "homeCity": "",
                        "notificationPreferences": NSNull(),
                        "profilePicture": NSNull()
                    ]) { error in
                        if let error = error {
                            print("Error saving user data: \(error.localizedDescription)")
                        } else {
                            print("User data saved successfully!")
                        }
                    }
                }
            }
        }
    }

    func clearFields() {
        self.firstNameField.text = nil
        self.lastNameField.text = nil
        self.emailField.text = nil
        self.phoneNumberField.text = nil
        self.passwordField.text = nil
        self.reenterPasswordField.text = nil
    }
    
    func switchToMainApp() {
            let sb = UIStoryboard(name: "Main", bundle: nil)
            let tab = sb.instantiateViewController(withIdentifier: "MainTabBarControllerID")

            tab.modalPresentationStyle = .fullScreen

            // iOS 13+ with SceneDelegate
            if let windowScene = view.window?.windowScene,
               let sceneDelegate = windowScene.delegate as? SceneDelegate {
                sceneDelegate.window?.rootViewController = tab
                sceneDelegate.window?.makeKeyAndVisible()
            }
        }


}
