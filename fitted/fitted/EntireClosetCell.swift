// EntireClosetCell.swift

import UIKit

class EntireClosetCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    // Connect this to the label's width constraint in IB
    @IBOutlet weak var titleWidthConstraint: NSLayoutConstraint!
    
    // The VC will set this based on its itemWidth calculation
    var cellWidth: CGFloat = 0 {
        didSet {
            // Give the label a little horizontal padding inside the cell
            let horizontalPadding: CGFloat = 8
            titleWidthConstraint.constant = max(0, cellWidth - horizontalPadding * 2)
            // Also update preferredMaxLayoutWidth so multi-line wrapping is correct
            titleLabel.preferredMaxLayoutWidth = titleWidthConstraint.constant
            layoutIfNeeded()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Make the label look like the Figma
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .center
    }
}
