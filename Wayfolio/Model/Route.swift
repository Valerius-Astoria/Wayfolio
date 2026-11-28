//
//  Route.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import CoreLocation
import SwiftData
import Foundation
import MapKit

/// One part of an adventure, usually a day: the waypoints to visit in order and the legs between them.
@Model class Route {
    var name: String
    var brief: String?
    var intro: String?
    var day: Int
    /// The route's position within its day. See `Adventure.routes(on:)`.
    var order: Int = 0
    var defaultTransportType: TransportType

    var adventure: Adventure

    @Relationship(deleteRule: .cascade, inverse: \Waypoint.route)
    var waypoints: [Waypoint] = []
    @Relationship(deleteRule: .cascade, inverse: \PointLeg.route)
    var pointLegs: [PointLeg] = []

    init(name: String,
         brief: String?,
         intro: String?,
         on day: Int,
         order: Int = 0,
         in adventure: Adventure,
         defaultTransportType: TransportType = .walking) {
        self.name = name
        self.brief = brief
        self.intro = intro
        self.day = day
        self.order = order
        self.adventure = adventure
        self.defaultTransportType = defaultTransportType
    }

    /// The waypoints, sorted by `order`.
    var orderedWaypoints: [Waypoint] {
        waypoints
            .sorted { $0.order < $1.order }
    }

    /// The waypoints' locations, in visit order.
    var coordinates: [CLLocationCoordinate2D] {
        orderedWaypoints.map(\.coordinate)
    }

    /// The legs, sorted by `order`.
    var orderedPointlegs: [PointLeg] {
        pointLegs
            .sorted { $0.order < $1.order }
    }

    /// The time span of the route, from the first waypoint's start to the last waypoint's end.
    ///
    /// All times are `0` if the route has no waypoints.
    var schedule: Schedule {
        let start = orderedWaypoints.first
        let end = orderedWaypoints.last
        return Schedule(startHour: start?.schedule.startHour ?? 0,
                        startMinute: start?.schedule.startMinute ?? 0,
                        endHour: end?.schedule.endHour ?? 0,
                        endMinute: end?.schedule.endMinute ?? 0)
    }

    /// - Returns: The leg that departs from `waypoint`, or `nil` if it's the last stop.
    func leg(from waypoint: Waypoint) -> PointLeg? {
        pointLegs.first { $0.startingPoint == waypoint }
    }
    
    // MARK: - Editing

    /// Whether this route already includes the Apple Maps place.
    func contains(_ item: MKMapItem) -> Bool {
        guard let id = item.identifier?.rawValue else { return false }
        return waypoints.contains { $0.poiIdentifier == id }
    }

    /// Appends a stop from an Apple Maps place, starting 15 minutes after this route's last waypoint and lasting 30 minutes.
    func addWaypoint(from item: MKMapItem) {
        let waypoint = Waypoint(
            item: item,
            name: nil,
            intro: nil,
            schedule: Schedule(following: orderedWaypoints.last?.schedule),
            order: (waypoints.map(\.order).max() ?? -1) + 1,
            route: self
        )
        if waypoints.contains(where: { $0 === waypoint }) {
            waypoints = Array(waypoints)
        } else {
            waypoints.append(waypoint)
        }
        rebuildLegs()
        try? modelContext?.save()
    }

    /// Removes the stop that matches the Apple Maps place, if it is on this route.
    func removeWaypoint(matching item: MKMapItem) {
        guard let id = item.identifier?.rawValue,
              let index = orderedWaypoints.firstIndex(where: { $0.poiIdentifier == id }) else { return }
        deleteWaypoints(at: IndexSet(integer: index))
    }

    /// Deletes the waypoints at `offsets` in `orderedWaypoints`, then renumbers the rest and reconnects them.
    ///
    /// Legs to or from a deleted waypoint are deleted too. See `rebuildLegs()`.
    func deleteWaypoints(at offsets: IndexSet) {
        let ordered = orderedWaypoints
        let doomedWaypoints = offsets.map { ordered[$0] }
        let remaining = ordered.filter { waypoint in
            doomedWaypoints.allSatisfy { $0 !== waypoint }
        }

        for (index, waypoint) in remaining.enumerated() {
            waypoint.order = index
        }
        waypoints = remaining
        // Rebuild before deleting, so no leg still points at a deleted waypoint.
        rebuildLegs()
        for waypoint in doomedWaypoints {
            modelContext?.delete(waypoint)
        }
        try? modelContext?.save()
    }

    /// Moves waypoints in `orderedWaypoints`, then reconnects the legs. See `rebuildLegs()`.
    func moveWaypoints(from source: IndexSet, to destination: Int) {
        var ordered = orderedWaypoints
        let moved = source.sorted().map { ordered[$0] }
        for index in source.sorted(by: >) {
            ordered.remove(at: index)
        }
        let insertion = min(destination - source.count(where: { $0 < destination }), ordered.count)
        ordered.insert(contentsOf: moved, at: insertion)
        for (index, waypoint) in ordered.enumerated() {
            waypoint.order = index
        }
        waypoints = ordered
        rebuildLegs()
        try? modelContext?.save()
    }

    /// Makes `pointLegs` connect each waypoint to the next one in `orderedWaypoints`.
    ///
    /// A leg that already joins the same two waypoints is kept, along with its transport type and recorded path.
    /// Missing legs are created with `defaultTransportType`, and legs that no longer join consecutive waypoints are deleted.
    func rebuildLegs() {
        let ordered = orderedWaypoints
        var unusedLegs = pointLegs
        var legs: [PointLeg] = []

        for (index, (start, end)) in zip(ordered, ordered.dropFirst()).enumerated() {
            if let match = unusedLegs.firstIndex(where: { $0.startingPoint == start && $0.endPoint == end }) {
                let leg = unusedLegs.remove(at: match)
                leg.order = index
                legs.append(leg)
            } else {
                legs.append(PointLeg(startingPoint: start,
                                     endPoint: end,
                                     transportType: defaultTransportType,
                                     order: index,
                                     route: self))
            }
        }

        pointLegs = legs
        for leg in unusedLegs {
            modelContext?.delete(leg)
        }
    }
}
