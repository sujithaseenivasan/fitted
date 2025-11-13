//
//  ClosetItemCell.swift
//  fitted
//
//  Created by Sarah Neville on 11/11/25.
//

import UIKit

class ClosetItemCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()

        // Make images display correctly inside the cell
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        // Center the text
        titleLabel.textAlignment = .center

        // Let long titles shrink instead of clipping
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6   // down to 60% of original size
        titleLabel.numberOfLines = 1          // single line that shrinks
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
    }
    
}
