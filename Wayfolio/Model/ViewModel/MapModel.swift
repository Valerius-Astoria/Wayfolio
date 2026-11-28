//
//  MapModel.swift
//  Wayfolio
//
//  Created by ZAKA on 11/27/26.
//

import Foundation
import MapKit
import SwiftUI
import SwiftData

@Observable
class MapModel: NSObject, MKLocalSearchCompleterDelegate {
    // MARK: - Map state
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(.beijing)) // 使用当前用户定位为地图地址，如果用户未授权，则定位至北京
    var selectedAdventure: Adventure?
    var selectedRoute: Route?
    var selectedWaypoint: Waypoint?
    /// Paths to draw for the current selection, grouped by route so each can use its own color.
    var drawnRoutes: [DrawnRoute] = []
    var navigationPath = NavigationPath() // Tracks the sheet's navigation stack

    /// Distinct colors for routes in an adventure. At most 10 routes are shown.
    static let routeColors: [Color] = [
        .blue, .orange, .green, .purple, .pink,
        .mint, .indigo, .teal, .brown, .cyan
    ]

    /// Changes when the map should reload polylines: a selected route, otherwise the selected adventure.
    var directionsSelectionID: PersistentIdentifier? {
        selectedRoute?.persistentModelID ?? selectedAdventure?.persistentModelID
    }

    /// Reloads directions when the selected adventure/route changes, or when its waypoints are edited.
    var directionsFingerprint: String {
        let parent = directionsSelectionID.map { String(describing: $0) } ?? ""
        let waypoints = visibleWaypoints
            .map { "\($0.persistentModelID):\($0.order):\($0.latitude):\($0.longitude)" }
            .joined(separator: ",")
        return "\(parent)|\(waypoints)"
    }

    /// Waypoints to pin on the map: the selected route's stops, or every stop in the selected adventure.
    var visibleWaypoints: [Waypoint] {
        if let selectedRoute {
            selectedRoute.orderedWaypoints
        } else if let selectedAdventure {
            selectedAdventure.orderedWaypoints
        } else {
            []
        }
    }
    
    func select(_ adventure: Adventure) {
        selectedAdventure = adventure
        selectedRoute = nil
        selectedWaypoint = nil
        
        guard let rect = Self.fittingRect(for: adventure.coordinates) else { return }
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .rect(rect)
        }
    }
    
    func select(_ route: Route) {
        selectedAdventure = route.adventure
        selectedRoute = route
        selectedWaypoint = nil
        
        guard let rect = Self.fittingRect(for: route.coordinates, minSideLength: 300) else { return }
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .rect(rect)
        }
    }
    
    func select(_ waypoint: Waypoint) {
        selectedWaypoint = waypoint
        focusCamera(on: waypoint)
        revealInSheet(waypoint)
    }

    /// Frames the map on `waypoint`.
    func focusCamera(on waypoint: Waypoint) {
        guard let rect = Self.fittingRect(for: [waypoint.coordinate], minSideLength: 100) else { return }
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .rect(rect)
        }
    }

    /// Replaces the sheet stack with adventure → route → waypoint so a map pin can open the matching pages.
    func revealInSheet(_ waypoint: Waypoint) {
        selectedAdventure = waypoint.route.adventure
        selectedRoute = waypoint.route
        selectedWaypoint = waypoint
        var path = NavigationPath()
        path.append(waypoint.route.adventure)
        path.append(waypoint.route)
        path.append(waypoint)
        navigationPath = path
    }

    /// After a back navigation, frames the map on the page that's now on top.
    func handleNavigationPop(from oldCount: Int, to newCount: Int) {
        guard newCount < oldCount else { return }
        switch newCount {
        case 2:
            if let selectedRoute { select(selectedRoute) }
        case 1:
            if let selectedAdventure { select(selectedAdventure) }
        default:
            selectedAdventure = nil
            selectedRoute = nil
            selectedWaypoint = nil
        }
    }

    /// The map color for `route`, based on its position among the adventure's routes.
    func color(for route: Route) -> Color {
        let index = route.adventure.orderedRoutes.firstIndex {
            $0.persistentModelID == route.persistentModelID
        } ?? 0
        return Self.routeColors[index % Self.routeColors.count]
    }

    /// Fills `drawnRoutes` from the current selection's point legs.
    ///
    /// A selected route uses only that route's legs; otherwise every leg of the selected adventure is used.
    /// Official legs request Apple Maps directions; recorded legs use their stored coordinates.
    func loadDirectionsForSelection() async {
        let routes: [Route] = if let selectedRoute {
            [selectedRoute]
        } else if let selectedAdventure {
            selectedAdventure.orderedRoutes
        } else {
            []
        }

        drawnRoutes = routes.map { route in
            route.rebuildLegs()
            return DrawnRoute(id: route.persistentModelID, color: color(for: route))
        }

        for (index, route) in routes.enumerated() {
            for leg in route.orderedPointlegs {
                if Task.isCancelled { return }
                if leg.useCustomRoute {
                    drawnRoutes[index].customPaths.append(leg.customPolylineCoordinates)
                } else if let mkRoute = try? await leg.getOfficialDirections() {
                    if Task.isCancelled { return }
                    drawnRoutes[index].officialPaths.append(mkRoute)
                }
            }
        }
    }
    
    // MARK: - Camera helper

    /// 根据给定坐标列表，计算包含全部坐标的地图矩形。
    private static func fittingRect(for coordinates: [CLLocationCoordinate2D], minSideLength: Double = 1000) -> MKMapRect? {
        guard !coordinates.isEmpty else { return nil }

        let rect = coordinates.reduce(MKMapRect.null) { partial, coordinate in
            let point = MKMapPoint(coordinate)
            return partial.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }

        // 最小边长约 1.5 公里，避免只有一个节点时放得太大
        let centerLatitude = MKMapPoint(x: rect.midX, y: rect.midY).coordinate.latitude
        let minSide = MKMapPointsPerMeterAtLatitude(centerLatitude) * minSideLength

        let width = max(rect.width * 1.4, minSide)
        let height = max(rect.height * 1.4, minSide)

        return MKMapRect(x: rect.midX - width / 2,
                         y: rect.midY - height / 2,
                         width: width,
                         height: height)
    }
}

/// Drawable geometry for one `Route`, including the color used for its path and pins.
struct DrawnRoute: Identifiable {
    let id: PersistentIdentifier
    let color: Color
    var officialPaths: [MKRoute] = []
    var customPaths: [[CLLocationCoordinate2D]] = []
}
