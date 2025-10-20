//
//  EventLineupViewController.swift
//  fitted
//
//  Created by Sarah Neville on 10/20/25.
//

import UIKit

struct Event {
    let title: String
    let description: String
    let location: String
    let dateText: String
    let image: UIImage?
}

class EventLineupViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
