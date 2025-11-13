//
//  ClosetFeedViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit

class ClosetFeedViewController: UIViewController {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    private var currentVC: UIViewController?

    
    var eventId: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSelectedSegment()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func segmentChanged(_ sender: Any) {
        loadSelectedSegment()
    }
    
    private func loadSelectedSegment() {
        let sb = UIStoryboard(name: "Main", bundle: nil)

        if segmentedControl.selectedSegmentIndex == 0 {
            // Closet Feed
            let vc = sb.instantiateViewController(withIdentifier: "ClosetFeedListVC") as! ClosetFeedListViewController
            vc.eventId = eventId
            showChild(vc)
        } else {
            // Entire Closet
            let vc = sb.instantiateViewController(withIdentifier: "EntireClosetGridVC") as! EntireClosetGridViewController
            vc.eventId = eventId
            showChild(vc)
        }
    }

    
    private func showChild(_ vc: UIViewController) {
        // Remove previous child
        if let current = currentVC {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        // Add new child
        addChild(vc)
        vc.view.frame = containerView.bounds
        containerView.addSubview(vc.view)
        vc.didMove(toParent: self)

        currentVC = vc
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
