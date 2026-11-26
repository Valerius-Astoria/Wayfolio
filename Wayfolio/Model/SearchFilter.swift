//
//  SearchFilter.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import MapKit
import SwiftUI

/// What to show in the search results, and how to narrow them down.
///
/// Within each group, a result matches if it has any of the selected values.
/// Across groups, it has to match every group. An empty group matches everything.
struct SearchFilter: Equatable {
    enum Scope: Hashable, CaseIterable {
        case all, adventures, places

        var name: LocalizedStringKey {
            switch self {
            case .all: "All"
            case .adventures: "Adventures"
            case .places: "Places"
            }
        }
    }

    var scope = Scope.all

    // Places
    var categories: Set<MKPointOfInterestCategory> = []

    // Adventures
    var types: Set<AdventureType> = []
    var lengths: Set<TripLength> = []

    var showsAdventures: Bool { scope != .places }
    var showsPlaces: Bool { scope != .adventures }

    /// Whether anything differs from the default, unfiltered state.
    var isActive: Bool { self != SearchFilter() }

    func matches(_ adventure: Adventure) -> Bool {
        (types.isEmpty || adventure.types.contains(where: types.contains))
            && (lengths.isEmpty || lengths.contains { $0.contains(adventure.dayCount) })
    }
}

/// How many days an adventure lasts, for filtering.
enum TripLength: Hashable, CaseIterable {
    case one, two, three, fourPlus

    var name: LocalizedStringKey {
        switch self {
        case .one: "1 day"
        case .two: "2 days"
        case .three: "3 days"
        case .fourPlus: "4+ days"
        }
    }

    func contains(_ dayCount: Int) -> Bool {
        switch self {
        case .one: dayCount == 1
        case .two: dayCount == 2
        case .three: dayCount == 3
        case .fourPlus: dayCount >= 4
        }
    }
}

extension MKPointOfInterestCategory {
    /// The categories offered in the search filter.
    static let common: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .museum, .park, .landmark,
        .hotel, .store, .publicTransport, .beach, .theater
    ]

    /// A display name, icon, and color, used for filter chips and place rows.
    var label: IconLabel {
        switch self {
        case .restaurant: IconLabel(name: "Restaurant", icon: "fork.knife", color: .orange)
        case .cafe: IconLabel(name: "Cafe", icon: "cup.and.saucer.fill", color: .brown)
        case .museum: IconLabel(name: "Museum", icon: "building.columns.fill", color: .pink)
        case .park: IconLabel(name: "Park", icon: "tree.fill", color: .green)
        case .landmark: IconLabel(name: "Landmark", icon: "star.fill", color: .yellow)
        case .hotel: IconLabel(name: "Hotel", icon: "bed.double.fill", color: .purple)
        case .store: IconLabel(name: "Store", icon: "bag.fill", color: .yellow)
        case .publicTransport: IconLabel(name: "Transit", icon: "tram.fill", color: .blue)
        case .beach: IconLabel(name: "Beach", icon: "beach.umbrella.fill", color: .cyan)
        case .theater: IconLabel(name: "Theater", icon: "theatermasks.fill", color: .indigo)
        default: IconLabel(name: "Place", icon: "mappin", color: .red)
        }
    }
}
