// EntireClosetCell.swift

import UIKit

class EntireClosetCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titleWidthConstraint: NSLayoutConstraint!
    
    var cellWidth: CGFloat = 0 {
        didSet {

            let horizontalPadding: CGFloat = 8
            titleWidthConstraint.constant = max(0, cellWidth - horizontalPadding * 2)
            titleLabel.preferredMaxLayoutWidth = titleWidthConstraint.constant
            layoutIfNeeded()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .center
    }
}
