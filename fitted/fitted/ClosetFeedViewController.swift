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
    
    weak var closetFeedListVC: ClosetFeedListViewController?

    var eventId: String!
    
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
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ], for: .selected)
        
        loadSelectedSegment()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSelectedSegment()
    }
    

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Only set up once, after segmentedControl has a proper frame
        if underlineView.superview == nil {
            configureUnderline()
        }

        // Make sure underline is in the right place after rotations/layout changes
        updateUnderlinePosition(animated: false)
    }

    private func configureUnderline() {
        underlineView.backgroundColor = .black
        underlineView.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addSubview(underlineView)

        let segmentWidth = segmentedControl.bounds.width / CGFloat(segmentedControl.numberOfSegments)

        underlineLeadingConstraint = underlineView.leadingAnchor.constraint(equalTo: segmentedControl.leadingAnchor)

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

    
    
    @IBAction func segmentChanged(_ sender: Any) {
        updateUnderlinePosition(animated: true)
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

    @IBAction func addItemButtonTapped(_ sender: Any) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(
            withIdentifier: "MyClosetViewController"
        ) as? MyClosetViewController else { return }

        vc.selectionEventId = eventId

        // when an item is added, refresh the list
        vc.onItemAddedToEvent = { [weak self] in
            self?.closetFeedListVC?.fetchEventItems()
        }

        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // this is the embed segue from the container view
        if let listVC = segue.destination as? ClosetFeedListViewController {
            closetFeedListVC = listVC
            listVC.eventId = eventId   // make sure it knows which event
        }
    }

}
