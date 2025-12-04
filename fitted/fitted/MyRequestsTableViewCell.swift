//
//  MyRequestsTableViewCell.swift
//  fitted
//
//  Created by Sarah Neville on 11/27/25.
//

import UIKit

protocol MyRequestsTableViewCellDelegate: AnyObject {
    func myRequestsCellDidTapCancel(_ cell: MyRequestsTableViewCell)
}

class MyRequestsTableViewCell: UITableViewCell {

    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var eventLabel: UILabel!
    @IBOutlet weak var requestedByLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var itemImage: UIImageView!
    
    weak var delegate: MyRequestsTableViewCellDelegate?
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        delegate?.myRequestsCellDidTapCancel(self)
    }
}
