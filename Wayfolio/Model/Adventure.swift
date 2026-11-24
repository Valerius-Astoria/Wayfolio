//
//  Adventure.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import SwiftData
import CoreLocation
internal import System

/// A multi-day trip, split into routes that each hold the waypoints to visit and the legs between them.
@Model class Adventure {
    var name: String
    var brief: String?
    var intro: String
    var region: String
    var status: Status
    
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

    init(name: String,
         brief: String?,
         intro: String,
         types: [AdventureType] = [],
         region: String,
         status: Status = .notStarted,
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

    /// The number of days the adventure lasts, taken from the highest `day` among its routes.
    ///
    /// `0` if there are no routes.
    var dayCount: Int {
        routes.map(\.day).max() ?? 0
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
struct Note: Codable, Identifiable {
    var id: UUID = UUID()

    /// An SF Symbol name.
    var icon: String
    var body: String
}

/// The user's progress through an adventure.
///
/// Stored in SwiftData by raw value, so renaming a case breaks existing data.
enum Status: String, Codable {
    case notStarted, stared, ended, abondened
}
