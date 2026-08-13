//
//  Item.swift
//  meta-vision
//
//  Created by Vidura Gunawardana on 2026-08-13.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
