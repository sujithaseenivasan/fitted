//
//  Group.swift
//  fitted
//
//  Created by Sarah Neville on 10/19/25.
//

import Foundation

struct Group {
    let id: String
    let name: String
    let photoURL: URL?
    let description: String?
    let ownerUid: String?

    // Failable initializer from Firestore document data
    init?(id: String, dict: [String: Any]) {
        self.id = id
        guard let name = dict["group_name"] as? String else { return nil }
        self.name = name
        if let urlString = dict["photo"] as? String, let url = URL(string: urlString) {
            self.photoURL = url
        } else {
            self.photoURL = nil
        }
        self.description = dict["description"] as? String
        self.ownerUid = dict["group_owner"] as? String
    }
}
