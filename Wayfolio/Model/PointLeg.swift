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
    var expectedTravelTime: Double? // in seconds
    var distance: Double?
    var order: Int
    
    var adventure: Adventure
    
    /// - Parameters estimatedMinutes: The estimated minutes
    init(startingPoint: Waypoint,
         endPoint: Waypoint,
         transportType: TransportType,
         order: Int,
         adventure: Adventure) {
        self.startingPoint = startingPoint
        self.endPoint = endPoint
        self.transportType = transportType
        self.order = order
        self.adventure = adventure
    }
    
    var useCustomRoute: Bool { !customCoordinates .isEmpty }
    
    /// Convenience for drawing the recorded path
    var customPolylineCoordinates: [CLLocationCoordinate2D] {
        customCoordinates.map(\.coordinate)
    }

    func getOfficialDirections() async throws -> MKRoute? {
        let request = MKDirections.Request()
        await request.source = startingPoint.getMKMapItem()
        await request.destination = endPoint.getMKMapItem()
        let route = try await MKDirections(request: request).calculate().routes.first
        self.expectedTravelTime = route?.expectedTravelTime
        self.distance = route?.distance
        return route
    }
    
    /// Continuously tracks the user's location (including in the background)
    /// and records the path plus the overall duration.
    ///
    /// Runs until the surrounding `Task` is cancelled, then saves `expectedTravelTime` and `distance`.
    @MainActor
    func buildCustomRoute() async throws {
        customCoordinates = []
        expectedTravelTime = 0
        distance = 0

        let startDate = Date()
        var lastLocation: CLLocation?

        // Runs on normal exit, error and cancellation, so the duration is always saved.
        defer {
            expectedTravelTime = Date().timeIntervalSince(startDate)
        }

        for try await location in LocationTracker.updates(maxAccuracy: 50, minimumDistance: 5) {
            customCoordinates.append(RouteCoordinate(location.coordinate))
            if let lastLocation {
                distance = (distance ?? 0) + location.distance(from: lastLocation)
            }
            lastLocation = location
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
    
    var systemImage: String {
        switch self {
        case .walking:
            "figure.walk"
        case .cycling:
            "figure.bicycle"
        case .automobile:
            "figure.car"
        case .transit:
            "bus"
        }
    }
    
    var label: String {
        switch self {
        case .walking:
            "walk"
        case .cycling:
            "ride"
        case .automobile:
            "drive"
        case .transit:
            "public"
        }
    }
}
