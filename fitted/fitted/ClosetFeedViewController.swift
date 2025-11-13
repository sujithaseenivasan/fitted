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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSelectedSegment()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSelectedSegment()
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
