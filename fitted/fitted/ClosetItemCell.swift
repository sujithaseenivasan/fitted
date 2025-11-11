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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
    }
    
}
