//
//  Adventure.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftData
import CoreLocation

@Model class Adventure {
    var name: String
    var brief: String
    var intro: String
    var notes: [Note] = []
    var trace: [RouteCoordinate] = []
    var status: Status = Status.notStarted
    
    @Relationship(deleteRule: .cascade, inverse: \Waypoint.adventure)
    var waypoints: [Waypoint] = []
    @Relationship(deleteRule: .cascade, inverse: \PointLeg.adventure)
    var pointLegs: [PointLeg] = []
    
    init(name: String, brief: String, intro: String, notes: [Note]) {
        self.name = name
        self.brief = brief
        self.intro = intro
    }
    
    /// Calculated using the highest `day` value from `waypoints`.
    var dayCount: Int {
        waypoints.map { $0.schedule.day }.max() ?? 0
    }
    
    /// An adventure is completed only when all waypoints are checked.
    var isChecked: Bool {
        waypoints.allSatisfy { $0.isChecked }
    }
    
    /// Track user location during adventure
    /// Tracks the user's location during the adventure and appends each point to `trace`.
    ///
    /// Runs until the surrounding `Task` is cancelled. Existing `trace` points are kept,
    /// so tracking can be stopped and resumed (for example across days).
    /// - Throws: `LocationError.permissionDenied` if the user denies location access.
    @MainActor
    func track(maxAccuracy: CLLocationAccuracy = 50, minimumDistance: CLLocationDistance = 10) async throws {
        for try await location in LocationTracker.updates(maxAccuracy: maxAccuracy,
                                                          minimumDistance: minimumDistance) {
            trace.append(RouteCoordinate(location.coordinate))
        }
    }
}

struct Note: Codable {
    var icon: String
    var bofy: String
}

enum Status: Codable {
    case notStarted, stared, ended, abondened
}
