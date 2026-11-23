//
//  Route.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftData

/// One part of an adventure, usually a day: the waypoints to visit in order and the legs between them.
@Model class Route {
    var name: String
    /// A one-line summary shown in lists.
    var brief: String
    /// The full introduction shown on the detail page.
    var intro: String
    /// The day of the adventure this route is on, starting from `1`.
    var day: Int

    var adventure: Adventure

    /// Deleting the route deletes its waypoints too.
    @Relationship(deleteRule: .cascade, inverse: \Waypoint.route)
    var waypoints: [Waypoint] = []
    /// Deleting the route deletes its legs too.
    @Relationship(deleteRule: .cascade, inverse: \PointLeg.route)
    var pointLegs: [PointLeg] = []

    /// Creates an empty route. Add waypoints and legs afterwards.
    ///
    /// - Parameters:
    ///   - day: The day of the adventure, starting from `1`.
    ///   - adventure: The adventure this route belongs to.
    init(name: String, brief: String, intro: String, on day: Int, in adventure: Adventure) {
        self.name = name
        self.brief = brief
        self.intro = intro
        self.day = day
        self.adventure = adventure
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

    /// The fraction of waypoints that are checked, from `0` to `1`.
    ///
    /// `NaN` if the route has no waypoints.
    var percentage: Double {
        Double(waypoints.count { $0.isChecked }) / Double(waypoints.count)
    }

    /// The time span of the route, from the first waypoint's start to the last waypoint's end.
    ///
    /// All times are `0` if the route has no waypoints.
    func schedule() -> Schedule {
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
}
