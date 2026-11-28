//
//  Adventure.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import SwiftData
import CoreLocation

/// A multi-day trip, split into routes that each hold the waypoints to visit and the legs between them.
@Model class Adventure {
    var name: String
    var brief: String?
    var intro: String
    var status: Status
    
    var notes: [Note] = []
    /// The path the user actually walked, recorded by `track(maxAccuracy:minimumDistance:)`.
    var trace: [RouteCoordinate] = []
    /// The categories the adventure belongs to, shown as icons. See `AdventureType.label`.
    var types: [AdventureType] = []

    /// The cover image, as JPEG data. Stored outside the database because it can be large.
    @Attribute(.externalStorage)
    var image: Data?
    /// The routes that make up the adventure, usually one per day. Deleting the adventure deletes them too.
    @Relationship(deleteRule: .cascade, inverse: \Route.adventure)
    var routes: [Route] = []

    init(name: String,
         brief: String?,
         intro: String,
         types: [AdventureType] = [],
         status: Status = .notStarted,
         image: Data? = nil) {
        self.name = name
        self.brief = brief
        self.intro = intro
        self.status = status
        self.types = types
        self.image = image
    }
    
    /// Every waypoint's location across all routes, for framing the map.
    var coordinates: [CLLocationCoordinate2D] {
        routes.flatMap(\.orderedWaypoints).map(\.coordinate)
    }

    /// Every waypoint across all routes, in day, route, and visit order.
    var orderedWaypoints: [Waypoint] {
        orderedRoutes.flatMap(\.orderedWaypoints)
    }

    /// Routes sorted by day, then by `order` within the day.
    var orderedRoutes: [Route] {
        routes.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.order < $1.order
        }
    }

    /// The total number of waypoints across all routes.
    var waypointCount: Int {
        routes.reduce(0) { $0 + $1.waypoints.count }
    }

    /// The number of days the adventure lasts, taken from the highest `day` among its routes.
    ///
    /// `0` if there are no routes.
    var dayCount: Int {
        routes.map(\.day).max() ?? 0
    }

    // MARK: Custom map items
    // Trace-recording UI is forthcoming. `trace` already persists with the adventure.

    /// Tracks the user's location during the adventure and appends each point to `trace`.
    ///
    /// Runs until the surrounding `Task` is cancelled. Existing `trace` points are kept,
    /// so tracking can be stopped and resumed (for example across days).
    /// - Parameters:
    ///   - maxAccuracy: Location fixes less accurate than this (in meters) are ignored.
    ///   - minimumDistance: Points closer than this (in meters) to the previous one are ignored.
    /// - Throws: `LocationError.permissionDenied` if the user denies location access.
    @MainActor
    func track(maxAccuracy: CLLocationAccuracy = 50, minimumDistance: CLLocationDistance = 10) async throws {
        for try await location in LocationTracker.updates(maxAccuracy: maxAccuracy,
                                                          minimumDistance: minimumDistance) {
            trace.append(RouteCoordinate(location.coordinate))
        }
    }
    
    func deleteNotes(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        try? modelContext?.save()
    }

    /// The routes on `day`, sorted by `order`.
    func routes(on day: Int) -> [Route] {
        routes.filter { $0.day == day }
            .sorted { $0.order < $1.order }
    }

    /// Adds an empty route at the end of `day`. No waypoints are created.
    ///
    /// Appends to `routes` so the list updates immediately. Linking only through
    /// `Route`'s `adventure` inverse is not observed until SwiftData autosaves.
    func addRoute(on day: Int) {
        let existing = routes(on: day)
        let route = Route(
            name: "New Route",
            brief: nil,
            intro: nil,
            on: day,
            order: (existing.map(\.order).max() ?? -1) + 1,
            in: self
        )
        if routes.contains(where: { $0 === route }) {
            routes = Array(routes)
        } else {
            routes.append(route)
        }
        try? modelContext?.save()
    }
    
    /// Deletes `doomedRoutes`, along with their waypoints and legs.
    func delete(_ doomedRoutes: [Route]) {
        routes.removeAll { doomedRoutes.contains($0) }
        for route in doomedRoutes {
            modelContext?.delete(route)
        }
        try? modelContext?.save()
    }

    // MARK: - Search

    /// Finds the adventures that match `query`.
    ///
    /// Matching ignores case and diacritics. Results are ranked by where the match was found:
    /// name, then brief, then intro. Adventures with the same rank are sorted by name.
    /// - Returns: The matching adventures, or all of `adventures` if `query` is blank.
    static func search(query: String, in adventures: [Adventure]) -> [Adventure] {
          let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !query.isEmpty else { return adventures }

          let matches: [(adventure: Adventure, rank: Int)] = adventures.compactMap { adventure in
              guard let rank = adventure.searchRank(for: query) else { return nil }
              return (adventure, rank)
          }

          return matches
              .sorted { lhs, rhs in
                  if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                  return lhs.adventure.name.localizedStandardCompare(rhs.adventure.name) == .orderedAscending
              }
              .map(\.adventure)
      }

    /// - Returns: `0` for a name match, `1` for a brief match, `2` for an intro match,
    ///   or `nil` if nothing matches. Lower is better.
    private func searchRank(for query: String) -> Int? {
        if name.localizedStandardContains(query) { return 0 }
        if brief?.localizedStandardContains(query) == true { return 1 }
        if intro.localizedStandardContains(query) { return 2 }
        return nil
    }
}

/// A short tip attached to an adventure.
struct Note: Codable, Identifiable {
    var id: UUID = UUID()

    /// An SF Symbol name. See `Symbol`.
    var icon: String
    var body: String

    /// The symbols offered when picking a note's icon, with the name shown in the menu.
    enum Symbol: String, CaseIterable, Identifiable, IconPickable {
        case weather = "sun.rain.fill"
        case food = "fork.knife"
        case money = "dollarsign.circle"
        case travel = "bus.fill"
        case others = "info.circle"

        var id: String { rawValue }
        var iconName: String { rawValue }

        var title: String {
            switch self {
            case .weather: "Weather"
            case .food: "Food"
            case .money: "Money"
            case .travel: "Travel"
            case .others: "Others"
            }
        }
    }
}

/// The user's progress through an adventure.
///
/// Stored in SwiftData by raw value, so renaming a case breaks existing data.
enum Status: String, Codable {
    case notStarted, stared, ended, abondened
}
