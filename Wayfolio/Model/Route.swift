//
//  Route.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftData
import Foundation

/// One part of an adventure, usually a day: the waypoints to visit in order and the legs between them.
@Model class Route {
    var name: String
    var brief: String?
    var intro: String?
    var day: Int
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
         in adventure: Adventure,
         defaultTransportType: TransportType = .walking) {
        self.name = name
        self.brief = brief
        self.intro = intro
        self.day = day
        self.adventure = adventure
        self.defaultTransportType = defaultTransportType
    }

    /// The waypoints, sorted by `order`.
    var orderedWaypoints: [Waypoint] {
        waypoints
            .sorted { $0.order < $1.order }
    }

    /// The legs, sorted by `order`.
    var orderedPointlegs: [PointLeg] {
        pointLegs
            .sorted { $0.order < $1.order }
    }
    
    
    // The number of checked waypoints.
    var checkedWaypointCount: Int {
        waypoints.count { $0.isChecked }
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

    /// Deletes the waypoints at `offsets` in `orderedWaypoints`, then renumbers the rest and reconnects them.
    ///
    /// Legs to or from a deleted waypoint are deleted too. See `rebuildLegs()`.
    func deleteWaypoints(at offsets: IndexSet) {
        let ordered = orderedWaypoints
        let doomedWaypoints = Set(offsets.map { ordered[$0] })

        waypoints = ordered.filter { !doomedWaypoints.contains($0) }
        for (index, waypoint) in waypoints.enumerated() {
            waypoint.order = index
        }
        // Rebuild before deleting, so no leg still points at a deleted waypoint.
        rebuildLegs()
        for waypoint in doomedWaypoints {
            modelContext?.delete(waypoint)
        }
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
