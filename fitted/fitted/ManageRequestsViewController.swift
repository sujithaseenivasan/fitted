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

    private lazy var inquiriesVC: MyInquiriesViewController = {
        let vc = storyboard!.instantiateViewController(
            withIdentifier: "MyInquiriesViewController"
        ) as! MyInquiriesViewController
        return vc
    }()

    private var currentChild: UIViewController?
    
    private let underlineView = UIView()
    private var underlineLeadingConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        segmentedControl.backgroundColor = .clear
        segmentedControl.selectedSegmentTintColor = .clear
        
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.darkGray,
            .font: UIFont.systemFont(ofSize: 16, weight: .regular)
        ], for: .normal)
        
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor(named: "SecondaryPink") ?? .darkGray,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ], for: .selected)

        segmentedControl.selectedSegmentIndex = 0
        showChild(myRequestsVC)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Only set up once, after segmentedControl has its final frame
        if underlineView.superview == nil {
            configureUnderline()
        }
        
        // Keep underline in the correct position on layout changes
        updateUnderlinePosition(animated: false)
    }
    
    private func configureUnderline() {
        underlineView.backgroundColor = UIColor(named: "SecondaryPink") ?? .black
        underlineView.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addSubview(underlineView)
        
        let segmentWidth = segmentedControl.bounds.width / CGFloat(segmentedControl.numberOfSegments)
        
        underlineLeadingConstraint = underlineView
            .leadingAnchor
            .constraint(equalTo: segmentedControl.leadingAnchor)
        
        NSLayoutConstraint.activate([
            underlineLeadingConstraint!,
            underlineView.bottomAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 2),
            underlineView.heightAnchor.constraint(equalToConstant: 2),
            underlineView.widthAnchor.constraint(equalToConstant: segmentWidth)
        ])
    }
    
    private func updateUnderlinePosition(animated: Bool) {
        let segmentWidth = segmentedControl.bounds.width / CGFloat(segmentedControl.numberOfSegments)
        underlineLeadingConstraint?.constant = segmentWidth * CGFloat(segmentedControl.selectedSegmentIndex)
        
        let animations = {
            self.segmentedControl.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, animations: animations)
        } else {
            animations()
        }
    }
    
    
    
    @IBAction func segmentedControlSwitch(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            showChild(myRequestsVC)
        case 1:
            showChild(inquiriesVC)
        default:
            break
        }
        // move underline when segment changes
        updateUnderlinePosition(animated: true)
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
