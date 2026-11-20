//
//  PointLeg.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import MapKit
import SwiftData

@Model class PointLeg {
    var startingPoint: Waypoint
    var endPoint: Waypoint
    var transportType: TransportType
    var customCoordinates: [RouteCoordinate] = []
    var estimatedMinutes: Int = 0 // The estimated minute for custom route
    
    /// - Parameters estimatedMinutes: The estimated minutes
    init(startingPoint: Waypoint, endPoint: Waypoint, transportType: TransportType) {
        self.startingPoint = startingPoint
        self.endPoint = endPoint
        self.transportType = transportType
    }
    
    var useCustomRoute: Bool { !customCoordinates .isEmpty }
    
    /// Convenience for drawing the recorded path
    var customPolylineCoordinates: [CLLocationCoordinate2D] {
        customCoordinates.map(\.coordinate)
    }

    func getOfficialDirections() async throws -> [MKRoute] {
        let request = MKDirections.Request()
        await request.source = startingPoint.getMKMapItem()
        await request.destination = endPoint.getMKMapItem()
        return try await MKDirections(request: request).calculate().routes
    }
    
    /// Continuously tracks the user's location (including in the background)
    /// and records the path plus the overall duration.
    ///
    /// Runs until the surrounding `Task` is cancelled, then saves `estimatedMinutes`.
    @MainActor
    func buildCustomRoute() async throws {
        customCoordinates = []
        estimatedMinutes = 0

        let startDate = Date()

        // Runs on normal exit, error and cancellation, so the duration is always saved.
        defer {
            let seconds = Date().timeIntervalSince(startDate)
            estimatedMinutes = max(1, Int((seconds / 60).rounded(.up)))
        }

        for try await location in LocationTracker.updates(maxAccuracy: 50, minimumDistance: 5) {
            customCoordinates.append(RouteCoordinate(location.coordinate))
        }
    }
}

struct RouteCoordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum TransportType: Codable {
    case walking, cycling, automobile, transit
}
