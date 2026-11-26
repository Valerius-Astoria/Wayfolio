//
//  MapModel.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import MapKit
import SwiftUI

/// A page in the search sheet's navigation stack, which the map also focuses on.
enum MapDestination: Hashable {
    case adventure(Adventure)
    case route(Route)
    case waypoint(Waypoint)
    case clue(Clue)
    case place(MKMapItem)

    /// The adventure the page belongs to, or `nil` for a place.
    var adventure: Adventure? {
        switch self {
        case .adventure(let adventure): adventure
        case .route(let route): route.adventure
        case .waypoint(let waypoint): waypoint.route.adventure
        case .clue(let clue): clue.waypoint.route.adventure
        case .place: nil
        }
    }

    /// The route the page belongs to, if any.
    var route: Route? {
        switch self {
        case .route(let route): route
        case .waypoint(let waypoint): waypoint.route
        case .clue(let clue): clue.waypoint.route
        case .adventure, .place: nil
        }
    }

    /// Whether `other` is the same kind of page, such as two waypoints.
    func isSameKind(as other: MapDestination) -> Bool {
        switch (self, other) {
        case (.adventure, .adventure), (.route, .route), (.waypoint, .waypoint),
             (.clue, .clue), (.place, .place): true
        default: false
        }
    }
}

/// The state shared by the map and the search sheet over it.
///
/// The camera follows the page on top of `path`, so detail views don't need to know about the map.
@Observable @MainActor
final class MapModel {
    /// The sheet's smallest height, which shows just the search bar.
    static let collapsedDetent = PresentationDetent.height(88)

    var path: [MapDestination] = [] {
        didSet { focus(on: path.last) }
    }
    var camera: MapCameraPosition = .automatic
    /// The part of the map the user is looking at, used to search nearby.
    var visibleRegion: MKCoordinateRegion?
    var detent: PresentationDetent = .medium
    /// The places found by the current search, pinned on the map.
    var placeResults: [MKMapItem] = []

    /// Opens `destination`, replacing the top page if it's the same kind, such as one waypoint for another.
    func show(_ destination: MapDestination) {
        if let last = path.last, last.isSameKind(as: destination) {
            if last != destination {
                path[path.count - 1] = destination
            }
        } else {
            path.append(destination)
        }
    }

    /// Opens `waypoint` under its adventure and route, so Back steps through the route and then the adventure.
    ///
    /// Pages after the adventure are replaced. The path changes once, so the camera moves straight to the waypoint.
    func showWaypoint(_ waypoint: Waypoint) {
        let adventure = waypoint.route.adventure
        let stops: [MapDestination] = [.route(waypoint.route), .waypoint(waypoint)]
        if let index = path.lastIndex(of: .adventure(adventure)) {
            path = Array(path[...index]) + stops
        } else {
            path += [.adventure(adventure)] + stops
        }
    }

    /// Moves the camera to frame `destination`. Leaves it where it is for the search page.
    private func focus(on destination: MapDestination?) {
        guard let destination else { return }

        let region: MKCoordinateRegion? = switch destination {
        case .adventure(let adventure):
            MKCoordinateRegion(fitting: adventure.routes.flatMap(\.waypoints).map(\.coordinate))
        case .route(let route):
            MKCoordinateRegion(fitting: route.waypoints.map(\.coordinate))
        case .waypoint(let waypoint):
            MKCoordinateRegion(center: waypoint.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        case .clue(let clue):
            MKCoordinateRegion(center: clue.waypoint.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        case .place(let item):
            MKCoordinateRegion(center: item.location.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
        }

        if detent == Self.collapsedDetent {
            detent = .medium
        }
        if let region {
            withAnimation(.smooth(duration: 0.8)) {
                camera = .region(Self.aboveSheet(region))
            }
        }
    }

    /// `region` grown and moved south, so its content sits in the top half of the screen, above the sheet.
    private static func aboveSheet(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        let span = region.span
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: region.center.latitude - span.latitudeDelta / 2,
                                           longitude: region.center.longitude),
            span: MKCoordinateSpan(latitudeDelta: span.latitudeDelta * 2, longitudeDelta: span.longitudeDelta))
    }
}

extension View {
    /// Registers the pages that `MapDestination` values open. Apply it inside the `NavigationStack`.
    func mapDestinations() -> some View {
        navigationDestination(for: MapDestination.self) { destination in
            switch destination {
            case .adventure(let adventure): AdventureDetail(adventure: adventure)
            case .route(let route): RouteDetail(route: route)
            case .waypoint(let waypoint): WaypointDetail(waypoint: waypoint)
            case .clue(let clue): ClueDetail(clue: clue)
            case .place(let item): PlaceDetail(item: item)
            }
        }
    }

    /// Gives previews of detail pages a navigation stack and map model, so their links work.
    func previewInMapStack() -> some View {
        NavigationStack {
            mapDestinations()
        }
        .environment(MapModel())
    }
}
