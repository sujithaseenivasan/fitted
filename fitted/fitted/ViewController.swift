//
//  ViewController.swift
//  fitted
//
//  Created by Sujitha Seenivasan on 10/2/25.
//

import UIKit

class ViewController: UIViewController {

    private var didSegue = false
    let segueIdentifier = "splashSegue"

    override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            print("Splash on screen")
            guard !didSegue else { return }
            didSegue = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.performSegue(withIdentifier: self.segueIdentifier, sender: self)
            }
        }
    }

