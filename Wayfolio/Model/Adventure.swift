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
    var region: String
    var status: AdventureStatus
    
    var notes: [Note] = []
    /// The path the user actually walked, recorded by `track(maxAccuracy:minimumDistance:)`.
    var trace: [RouteCoordinate] = []
    /// The categories the adventure belongs to, shown as icons. See `AdventureType.label`.
    var types: [AdventureType] = []
    /// Free-form keywords used by `search(query:in:)`, such as the book or movie it's based on.
    var tags: [String] = []

    /// The cover image, as JPEG data. Stored outside the database because it can be large.
    @Attribute(.externalStorage)
    var image: Data
    /// The routes that make up the adventure, usually one per day. Deleting the adventure deletes them too.
    @Relationship(deleteRule: .cascade, inverse: \Route.adventure)
    var routes: [Route] = []
    /// The waypoint the user was last on while the adventure was running, where Resume returns to.
    @Relationship(deleteRule: .nullify)
    var currentWaypoint: Waypoint?

    init(name: String,
         brief: String?,
         intro: String,
         types: [AdventureType] = [],
         region: String,
         status: AdventureStatus = .notStarted,
         tags: [String],
         image: Data) {
        self.name = name
        self.brief = brief
        self.intro = intro
        self.status = status
        self.types = types
        self.region = region
        self.tags = tags
        self.image = image
    }

    /// The total number of waypoints across all routes.
    var waypointCount: Int {
        routes.reduce(0) { $0 + $1.waypoints.count }
    }

    /// The number of checked waypoints across all routes.
    var checkedWaypointCount: Int {
        routes.reduce(0) { $0 + $1.checkedWaypointCount }
    }

    /// The number of days the adventure lasts, taken from the highest `day` among its routes.
    ///
    /// `0` if there are no routes.
    var dayCount: Int {
        routes.map(\.day).max() ?? 0
    }
    
    /// The days that have at least one route, in order.
    var days: [Int] {
        Set(routes.map(\.day)).sorted()
    }

    /// The routes on `day`, sorted by `order`.
    func routes(on day: Int) -> [Route] {
        routes
            .filter { $0.day == day }
            .sorted { $0.order < $1.order }
    }

    // MARK: - Running

    /// Every waypoint in the order they're visited: by day, then route, then stop.
    var orderedWaypoints: [Waypoint] {
        days.flatMap { routes(on: $0) }.flatMap(\.orderedWaypoints)
    }

    var firstWaypoint: Waypoint? {
        orderedWaypoints.first
    }

    /// The stop after `waypoint`, continuing into the next route or day. `nil` after the last one.
    func waypoint(after waypoint: Waypoint) -> Waypoint? {
        let ordered = orderedWaypoints
        guard let index = ordered.firstIndex(of: waypoint), index + 1 < ordered.count else { return nil }
        return ordered[index + 1]
    }

    /// Where Resume takes the user: the last waypoint they were on, otherwise the first one not yet checked.
    var resumeWaypoint: Waypoint? {
        currentWaypoint ?? orderedWaypoints.first { !$0.isChecked } ?? firstWaypoint
    }

    /// Starts the adventure over: clears all progress and the recorded trace, and runs it from the first stop.
    func restart() {
        for waypoint in routes.flatMap(\.waypoints) {
            waypoint.resetProgress()
        }
        trace = []
        currentWaypoint = firstWaypoint
        status = .started
    }

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

    // MARK: - Editing

    func addNote(icon: String, body: String) {
        notes.append(Note(icon: icon, body: body))
    }

    func moveNotes(from source: IndexSet, to destination: Int) {
        notes.move(fromOffsets: source, toOffset: destination)
    }

    func deleteNotes(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
    }

    /// Adds a route at the end of `day`.
    @discardableResult
    func addRoute(name: String, day: Int, transportType: TransportType) -> Route {
        let route = Route(name: name,
                          brief: nil,
                          intro: nil,
                          on: day,
                          order: routes(on: day).count,
                          in: self,
                          defaultTransportType: transportType)
        // Creating it with this parent may already have linked it through the inverse relationship.
        if !routes.contains(route) {
            routes.append(route)
        }
        return route
    }

    /// Moves `dayRoutes` onto `day`, in the given order.
    func arrange(_ dayRoutes: [Route], on day: Int) {
        for (index, route) in dayRoutes.enumerated() {
            route.day = day
            route.order = index
        }
    }
    
    /// Deletes `doomedRoutes`, along with their waypoints and legs.
    func delete(_ doomedRoutes: [Route]) {
        routes.removeAll { doomedRoutes.contains($0) }
        for route in doomedRoutes {
            modelContext?.delete(route)
        }
    }

    // MARK: - Search

    /// Finds the adventures that match `query`.
    ///
    /// Matching ignores case and diacritics. Results are ranked by where the match was found:
    /// name, then tags, then region. Adventures with the same rank are sorted by name.
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

    /// - Returns: `0` for a name match, `1` for a tag match, `2` for a region match,
    ///   or `nil` if nothing matches. Lower is better.
    private func searchRank(for query: String) -> Int? {
        if name.localizedStandardContains(query) { return 0 }
        if tags.contains(where: { $0.localizedStandardContains(query)} ) { return 1 }
        if region.localizedStandardContains(query) { return 2 }
        return nil
    }
}

/// A short tip attached to an adventure.
nonisolated struct Note: Codable, Identifiable {
    var id: UUID = UUID()

    /// An SF Symbol name.
    var icon: String
    var body: String
}

/// The user's progress through an adventure.
///
/// Stored in SwiftData by raw value, so renaming a case breaks existing data.
nonisolated enum AdventureStatus: String, Codable {
    case notStarted
    /// Running: the user is on the adventure now.
    case started
    /// Stopped for now. Resume continues from `Adventure.currentWaypoint`.
    case paused
    /// Finished, with every waypoint checked.
    case checked
    /// Stopped before every waypoint was checked.
    case ended
}
