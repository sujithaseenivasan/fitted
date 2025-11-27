//
//  ManageRequestsViewController.swift
//  fitted
//
//  Created by Sarah Neville on 11/26/25.
//

import UIKit

class ManageRequestsViewController: UIViewController {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var containerView: UIView!
    
    // Keep references to the two child VCs
    private lazy var myRequestsVC: MyRequestsViewController = {
        let vc = storyboard!.instantiateViewController(
            withIdentifier: "MyRequestsViewController"
        ) as! MyRequestsViewController
        return vc
    }()

//    private lazy var inquiriesVC: InquiriesViewController = {
//        let vc = storyboard!.instantiateViewController(
//            withIdentifier: "InquiriesViewController"
//        ) as! InquiriesViewController
//        return vc
//    }()

    private var currentChild: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        segmentedControl.selectedSegmentIndex = 0
        showChild(myRequestsVC)
    }
    
    @IBAction func segmentedControlSwitch(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            showChild(myRequestsVC)
        case 1:
            break
            //showChild(inquiriesVC)
        default:
            break
        }
    }
    
    private func showChild(_ vc: UIViewController) {
        // Remove current child if any
        if let current = currentChild {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        // Add new child
        addChild(vc)
        vc.view.frame = containerView.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(vc.view)
        vc.didMove(toParent: self)

        currentChild = vc
    }

}
