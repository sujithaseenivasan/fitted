//
//  MyInquiriesTableViewCell.swift
//  fitted
//
//  Created by Sujitha Seenivasan on 12/1/25.
//

import UIKit

protocol MyInquiriesCellDelegate: AnyObject {
    func inquiryCellDidTapApprove(_ cell: MyInquiriesTableViewCell)
    func inquiryCellDidTapDeny(_ cell: MyInquiriesTableViewCell)
}

class MyInquiriesTableViewCell: UITableViewCell {

    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var requestedByLabel: UILabel!
    @IBOutlet weak var groupLabel: UILabel!
    @IBOutlet weak var eventLabel: UILabel!
    @IBOutlet weak var approveButton: UIButton!
    @IBOutlet weak var denyButton: UIButton!

    weak var delegate: MyInquiriesCellDelegate?

    // Programmatic labels
    let statusLabel = UILabel()
    let contactLabel = UILabel()

    override func awakeFromNib() {
        super.awakeFromNib()
        setupStatusAndContactLabels()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // reset so reused cells don't keep old text/state
        statusLabel.text = nil
        contactLabel.text = nil
        statusLabel.isHidden = true
        contactLabel.isHidden = true
        approveButton.isHidden = false
        denyButton.isHidden = false
    }

    private func setupStatusAndContactLabels() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contactLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(statusLabel)
        contentView.addSubview(contactLabel)

        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        statusLabel.textColor = .accentColorGreen
        statusLabel.textAlignment = .left

        contactLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        contactLabel.textColor = .darkGray
        contactLabel.textAlignment = .left
        contactLabel.numberOfLines = 0

        // Start hidden; controller will decide when to show
        statusLabel.isHidden = true
        contactLabel.isHidden = true

        NSLayoutConstraint.activate([
            // Place directly under the eventLabel, same leading edge
            statusLabel.leadingAnchor.constraint(equalTo: eventLabel.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: eventLabel.bottomAnchor, constant: 6),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),

            contactLabel.leadingAnchor.constraint(equalTo: statusLabel.leadingAnchor),
            contactLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            contactLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            contactLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    // MARK: - Actions

    @IBAction func approveTapped(_ sender: UIButton) {
        delegate?.inquiryCellDidTapApprove(self)
    }

    @IBAction func denyTapped(_ sender: UIButton) {
        delegate?.inquiryCellDidTapDeny(self)
    }
}
