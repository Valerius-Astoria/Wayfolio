//
//  AdventureType.swift
//  Wayfolio
//
//  Created by ZAKA on 11/22/26.
//

import Foundation
import SwiftUI

/// A category of adventure. An adventure can have several types.
///
/// Stored in SwiftData by raw value, so don't reorder or remove existing cases once real data exists.
/// Sorting follows the raw value.
enum AdventureType: Int, Codable, Comparable {
    static func < (lhs: AdventureType, rhs: AdventureType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    case hiking = 0, cityWalk, festival
    /// Visiting real places from books, movies, games, and other stories.
    case pilgrimage

    /// The display name, icon, and color for this type.
    var label: AdventureLabel {
        switch self {
        case .hiking:     AdventureLabel(name: "hiking",     icon: "figure.hiking",     color: .green)
        case .cityWalk:   AdventureLabel(name: "city walk",  icon: "building.2.fill",   color: .orange)
        case .festival:   AdventureLabel(name: "festival",   icon: "party.popper.fill", color: .pink)
        case .pilgrimage: AdventureLabel(name: "pilgrimage", icon: "book.pages.fill",   color: .indigo)
        }
    }
}

/// How an `AdventureType` is displayed.
struct AdventureLabel {
    var name: String
    /// An SF Symbol name.
    var icon: String
    var color: Color
}
