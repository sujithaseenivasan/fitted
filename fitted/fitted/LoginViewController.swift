//
//  LoginViewController.swift
//  fitted
//
//  Created by Sujitha Seenivasan on 10/8/25.
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
   
    @IBOutlet weak var errorLabel: UILabel!
    
    let segueIdentifier = "homeSegue1"
    private var didSwapRoot = false
    
    @IBOutlet weak var loginTextLabel: UILabel!
    
    @IBOutlet weak var alreadyHaveAcctTextLabel: UILabel!
    
    @IBOutlet weak var forgotPasswordButton: UIButton!
    
    @IBOutlet weak var createAccountButton: UIButton!
    
    @IBOutlet weak var loginButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Login on screen")
        self.errorLabel.text = ""
        // Listener to check if a user has logged in and initiate segue
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
                    guard let self = self, user != nil, !self.didSwapRoot else { return }
                    self.didSwapRoot = true
                    self.clearFields()
                    DispatchQueue.main.async { self.switchToMainApp() }
                }
        
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
    }
    
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    @IBAction func loginPressed(_ sender: Any) {
        if emailTextField.text != "" && passwordTextField.text != "" {
            Auth.auth().signIn(withEmail: emailTextField.text!,
                               password: passwordTextField.text!) {
                (authResult, error) in
                if let error = error as NSError? {
                    self.errorLabel.text = "\(error.localizedDescription)"
                } else if !self.didSwapRoot {
                    self.errorLabel.text = ""
                    self.didSwapRoot = true
                    self.clearFields()
                    self.switchToMainApp()
                }
            }
        }
    }
    
    func clearFields() {
        self.emailTextField.text = nil
        self.passwordTextField.text = nil
    }
    
    @IBAction func forgotPassword(_ sender: Any) {
        //changePassword(emailTextField.text!)
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
