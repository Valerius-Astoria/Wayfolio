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
/// The path comes from a recording made with `buildCustomRoute()` if there is one,
/// otherwise from Apple Maps directions. See `pathCoordinates`.
@Model class PointLeg {
    var startingPoint: Waypoint
    var endPoint: Waypoint
    var transportType: TransportType
    
    /// The path the user recorded with `buildCustomRoute()`.
    var customCoordinates: [RouteCoordinate] = []
    /// The path of the Apple Maps directions, saved by `getOfficialDirections()`.
    var directionCoordinates: [RouteCoordinate] = []
    var expectedTravelTime: Double?
    var distance: Double?
    var order: Int

    var route: Route

    init(startingPoint: Waypoint,
         endPoint: Waypoint,
         transportType: TransportType,
         order: Int,
         route: Route) {
        self.startingPoint = startingPoint
        self.endPoint = endPoint
        self.transportType = transportType
        self.order = order
        self.route = route
    }

    var useCustomRoute: Bool { !customCoordinates.isEmpty }

    /// Whether the leg still needs Apple Maps directions: it has neither a recording nor directions.
    var needsDirections: Bool { !useCustomRoute && directionCoordinates.isEmpty }

    /// The path to draw on the map: the recording, otherwise the directions,
    /// otherwise a straight line until directions arrive.
    var pathCoordinates: [CLLocationCoordinate2D] {
        let path = useCustomRoute ? customCoordinates : directionCoordinates
        guard !path.isEmpty else { return [startingPoint.coordinate, endPoint.coordinate] }
        return path.map(\.coordinate)
    }

    /// Requests directions from Apple Maps and saves the travel time, distance, and path.
    ///
    /// - Returns: The first route found, or `nil` if there is none.
    /// - Throws: An `MKError` if the directions request fails.
    func getOfficialDirections() async throws -> MKRoute? {
        let request = MKDirections.Request()
        await request.source = startingPoint.getMKMapItem()
        await request.destination = endPoint.getMKMapItem()
        request.transportType = transportType.directionsTransportType
        let route = try await MKDirections(request: request).calculate().routes.first
        self.expectedTravelTime = route?.expectedTravelTime
        self.distance = route?.distance
        self.directionCoordinates = route?.polyline.coordinates.map(RouteCoordinate.init) ?? []
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
nonisolated struct RouteCoordinate: Codable, Hashable {
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
nonisolated enum TransportType: CaseIterable, Codable {
    case walking, cycling, automobile, transit

    /// The display name and icon, such as "Walk" and `figure.walk`.
    var label: IconLabel {
        switch self {
        case .walking:
            IconLabel(name: "Walk", icon: "figure.walk")
        case .cycling:
            IconLabel(name: "Cycle", icon: "bicycle")
        case .automobile:
            IconLabel(name: "Drive", icon: "car.fill")
        case .transit:
            IconLabel(name: "Transit", icon: "bus.fill")
        }
    }
    
    /// The matching transport type for an Apple Maps directions request.
    var directionsTransportType: MKDirectionsTransportType {
        switch self {
        case .walking:
            .walking
        case .cycling:
            .cycling
        case .automobile:
            .automobile
        case .transit:
            .transit
        }
    }
}
