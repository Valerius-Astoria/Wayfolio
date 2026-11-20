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
        self.notes = notes
    }
    
    /// Calculated using the highest `day` value from `waypoints`.
    var dayCount: Int {
        waypoints.map { $0.schedule.day }.max() ?? 0
    }
    
    /// An adventure is completed only when all waypoints are checked.
    var isChecked: Bool {
        waypoints.allSatisfy { $0.isChecked }
    }
    
    /// - Returns: Days that have waypoints to visit. 
    var days: [Int] {
        Set(waypoints.map(\.schedule.day)).sorted()
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
    
    /// - Returns: An array of waypoints on `day` in order.
    func waypoints(on day: Int) -> [Waypoint] {
        waypoints
            .filter { $0.schedule.day == day }
            .sorted { $0.order < $1.order }
    }
    
    /// The leg that departs from `waypoint`, if any.
    func leg(from waypoint: Waypoint) -> PointLeg? {
        pointLegs.first { $0.startingPoint == waypoint }
    }
    
    // MARK: - Sample Data
    static let sampleData: [Adventure] = [
        Adventure(
            name: "MyAdventure",
            brief: "An adventure we all like, an adventure we all admire.",
            intro: "This is a really cool adventure that brings you back to the laet centry. During this adventure, you'll visit the village tha t only exists in your imagination, rivers as clear as crystle, and status so vivid that you doubt if they are real.",
            notes: [
                Note(icon: "bus", body: "Remember to take buses as you can, taxies are expensive"),
                Note(icon: "umbrella", body: "Always bring an unbrella with you, it rains a lot")
            ])
    ]
}

struct Note: Codable, Identifiable {
    var id: UUID = UUID()
    
    var icon: String
    var body: String
}

enum Status: String, Codable {
    case notStarted, stared, ended, abondened
}
