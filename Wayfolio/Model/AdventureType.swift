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
enum AdventureType: Int, Codable, Comparable, CaseIterable {
    static func < (lhs: AdventureType, rhs: AdventureType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    case hiking = 0, cityWalk, festival, pilgrimage

    /// The display name, icon, and color for this type.
    var label: IconLabel {
        switch self {
        case .hiking:     IconLabel(name: "hiking", icon: "figure.hiking",     color: .green)
        case .cityWalk:   IconLabel(name: "cityWalk", icon: "building.2.fill",   color: .orange)
        case .festival:   IconLabel(name: "festival", icon: "party.popper.fill", color: .pink)
        case .pilgrimage: IconLabel(name: "pilgrimage", icon: "book.pages.fill",   color: .indigo)
        }
    }
}

struct IconLabel: Hashable {
    var name: String
    var icon: String
    var color: Color = .accentColor
}
