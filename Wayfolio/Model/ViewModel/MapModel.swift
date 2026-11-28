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
    /// Follows the user; falls back to Beijing if location is unavailable.
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(.beijing))
    var selectedAdventure: Adventure?
    var selectedRoute: Route?
    var selectedWaypoint: Waypoint?
    /// The Apple Maps place currently shown in the sheet, if any.
    var selectedPOI: MKMapItem?
    /// Paths to draw for the current selection, grouped by route so each can use its own color.
    var drawnRoutes: [DrawnRoute] = []
    var navigationPath = NavigationPath() // Tracks the sheet's navigation stack
    /// Height of the search sheet over the map.
    var sheetDetent: PresentationDetent = .medium
    /// `RouteDetail`'s edit mode. Stays on while a POI is pushed so that page can add a waypoint.
    var routeEditMode: EditMode = .inactive
    var isEditingRoute: Bool {
        get { routeEditMode.isEditing }
        set { routeEditMode = newValue ? .active : .inactive }
    }
    /// Skips camera updates when the path is rewritten while a POI page is on screen.
    private var ignoreNextPop = false

    /// The map area currently on screen, used to rank place-search results.
    var visibleRegion: MKCoordinateRegion = .beijing
    /// Autocomplete suggestions for the route editor's place search.
    var placeCompletions: [MKLocalSearchCompletion] = []
    /// The place picked from search, shown as a highlighted marker on the map.
    var highlightedPlace: MKMapItem?
    @ObservationIgnored
    private let searchCompleter = MKLocalSearchCompleter()

    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.pointOfInterest, .address]
    }

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
        isEditingRoute = false
        
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
        focusCamera(on: waypoint.coordinate)
    }

    /// Frames the map on an Apple Maps place.
    func focusCamera(on item: MKMapItem) {
        focusCamera(on: item.location.coordinate)
    }

    /// Frames the map on `coordinate`.
    func focusCamera(on coordinate: CLLocationCoordinate2D) {
        guard let rect = Self.fittingRect(for: [coordinate], minSideLength: 150) else { return }
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .rect(rect)
        }
    }

    /// Updates place autocomplete, preferring results near the current camera.
    func searchPlaces(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            placeCompletions = []
            searchCompleter.queryFragment = ""
            return
        }
        searchCompleter.region = visibleRegion
        searchCompleter.queryFragment = trimmed
    }

    /// Resolves a completion, highlights it, moves the camera, collapses the sheet, and opens `POIDetailView`.
    func selectPlace(_ completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = visibleRegion
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return }
        highlightedPlace = item
        focusCamera(on: item)
        sheetDetent = .medium
        revealInSheet(item)
    }

    /// Replaces the sheet stack with adventure → route → waypoint so a map pin can open the matching pages.
    func revealInSheet(_ waypoint: Waypoint) {
        if selectedPOI != nil {
            ignoreNextPop = true
            selectedPOI = nil
        }
        selectedAdventure = waypoint.route.adventure
        selectedRoute = waypoint.route
        selectedWaypoint = waypoint
        var path = NavigationPath()
        path.append(waypoint.route.adventure)
        path.append(waypoint.route)
        path.append(waypoint)
        navigationPath = path
    }

    /// Pushes the place onto the current sheet stack so Back returns to the page underneath.
    func revealInSheet(_ item: MKMapItem) {
        if let currentID = selectedPOI?.identifier?.rawValue,
           currentID == item.identifier?.rawValue {
            return
        }
        if selectedPOI != nil {
            ignoreNextPop = true
            navigationPath.removeLast()
        }
        selectedPOI = item
        navigationPath.append(item)
    }

    /// After a back navigation, frames the map on the page that's now on top.
    func handleNavigationPop(from oldCount: Int, to newCount: Int) {
        guard newCount < oldCount else { return }
        if ignoreNextPop {
            ignoreNextPop = false
            return
        }
        if selectedPOI != nil {
            selectedPOI = nil
            return
        }
        switch newCount {
        case 2:
            if let selectedRoute { select(selectedRoute) }
        case 1:
            if let selectedAdventure { select(selectedAdventure) }
        default:
            selectedAdventure = nil
            selectedRoute = nil
            selectedWaypoint = nil
            isEditingRoute = false
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

    /// A map rectangle that contains every coordinate, padded so a single point isn't zoomed in too tightly.
    private static func fittingRect(for coordinates: [CLLocationCoordinate2D], minSideLength: Double = 1000) -> MKMapRect? {
        guard !coordinates.isEmpty else { return nil }

        let rect = coordinates.reduce(MKMapRect.null) { partial, coordinate in
            let point = MKMapPoint(coordinate)
            return partial.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }

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

// MARK: - MKLocalSearchCompleterDelegate

extension MapModel {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        placeCompletions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        placeCompletions = []
    }
}

/// Drawable geometry for one `Route`, including the color used for its path and pins.
struct DrawnRoute: Identifiable {
    let id: PersistentIdentifier
    let color: Color
    var officialPaths: [MKRoute] = []
    var customPaths: [[CLLocationCoordinate2D]] = []
}
