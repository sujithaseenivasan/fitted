//
//  GroupCardCell.swift
//  fitted
//
//  Created by Sarah Neville on 10/6/25.
//

import UIKit

class GroupCardCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var logoImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        // For shadow, apply to cell's layer, not containerView (if you want shadow)
//        contentView.layer.shadowColor = UIColor.black.cgColor
//        contentView.layer.shadowOpacity = 0.1
//        contentView.layer.shadowRadius = 4
//        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
//        contentView.layer.masksToBounds = false
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        logoImageView.image = nil
    }
}
