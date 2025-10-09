//
//  ClosetShareGroupsViewController.swift
//  fitted
//
//  Created by Sarah Neville on 10/6/25.
//

import UIKit

class ClosetShareGroupsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    

    @IBOutlet weak var joinGroupButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    //var groups: [Group] = [...] // replace with data from Firebase
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell()
    }

}
