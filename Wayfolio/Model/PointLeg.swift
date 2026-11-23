//
//  PointLeg.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import MapKit
import SwiftData

/// The journey between two consecutive waypoints.
///
/// The route comes either from Apple Maps directions or from a path the user recorded
/// with `buildCustomRoute()`.
@Model class PointLeg {
    var startingPoint: Waypoint
    var endPoint: Waypoint
    var transportType: TransportType
    /// The recorded path. Empty unless `buildCustomRoute()` has been run.
    var customCoordinates: [RouteCoordinate] = []
    /// Travel time, in seconds.
    var expectedTravelTime: Double?
    /// Travel distance, in meters.
    var distance: Double?
    /// The position of this leg within the adventure.
    var order: Int

    var adventure: Adventure

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

    /// Whether the leg uses a recorded path instead of Apple Maps directions.
    var useCustomRoute: Bool { !customCoordinates .isEmpty }

    /// The recorded path as coordinates, ready for drawing a `MapPolyline`.
    var customPolylineCoordinates: [CLLocationCoordinate2D] {
        customCoordinates.map(\.coordinate)
    }

    /// Requests directions from Apple Maps and saves the travel time and distance.
    ///
    /// - Returns: The first route found, or `nil` if there is none.
    /// - Throws: An `MKError` if the directions request fails.
    func getOfficialDirections() async throws -> MKRoute? {
        let request = MKDirections.Request()
        await request.source = startingPoint.getMKMapItem()
        await request.destination = endPoint.getMKMapItem()
        let route = try await MKDirections(request: request).calculate().routes.first
        self.expectedTravelTime = route?.expectedTravelTime
        self.distance = route?.distance
        return route
    }

    /// Records the user's path as the route for this leg, including while the app is in the background.
    ///
    /// Clears any previous recording. Runs until the surrounding `Task` is cancelled.
    /// `distance` is updated as the user moves, and `expectedTravelTime` is set to
    /// the total duration when recording stops.
    /// - Throws: `LocationError.permissionDenied` if the user denies location access.
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

/// A `Codable` stand-in for `CLLocationCoordinate2D`, so coordinates can be stored with SwiftData.
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

/// How the user travels along a leg.
enum TransportType: Codable {
    case walking, cycling, automobile, transit

    /// An SF Symbol name for the transport type.
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

    /// A short display name, such as "walk".
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
