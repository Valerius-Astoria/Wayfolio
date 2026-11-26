//
//  MapScreen.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import MapKit
import SwiftData
import SwiftUI

/// The home screen: a full-screen map with `SearchSheet` over it.
///
/// The map shows what the sheet's top page is about. On the search page that's every adventure
/// and the places found; inside an adventure, its waypoints and routes; on a place, just that place.
/// Tapping a pin opens its page in the sheet.
struct MapScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Adventure.name) private var adventures: [Adventure]

    @State private var map = MapModel()
    /// The tapped pin. Reset as soon as its page opens, so the same pin can be tapped again.
    @State private var selection: MapDestination?

    var body: some View {
        Map(position: $map.camera, selection: $selection) {
            UserAnnotation()

            switch map.path.last {
            case .place(let item)?:
                Marker(item: item)
                    .tag(MapDestination.place(item))
            case let destination?:
                if let adventure = destination.adventure {
                    adventureContent(adventure, focusedRoute: destination.route)
                }
            case nil:
                homeContent
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            map.visibleRegion = context.region
        }
        // Inside an adventure, fetch the directions its routes are drawn with.
        .task(id: map.path.last?.adventure) {
            guard let adventure = map.path.last?.adventure else { return }
            for route in adventure.routes {
                await route.loadMissingDirections()
            }
        }
        .onChange(of: selection) {
            guard let selection else { return }
            map.show(selection)
            self.selection = nil
        }
        .sheet(isPresented: .constant(true)) {
            @Bindable var map = map
            SearchSheet()
                .presentationDetents([MapModel.collapsedDetent, .medium, .large], selection: $map.detent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
                .environment(map)
                .environment(\.modelContext, modelContext)
        }
    }

    // MARK: - Content

    /// A cover pin for each adventure, and a marker for each place found.
    @MapContentBuilder
    private var homeContent: some MapContent {
        ForEach(adventures) { adventure in
            if let center = MKCoordinateRegion(fitting: adventure.routes.flatMap(\.waypoints).map(\.coordinate))?.center {
                Annotation(adventure.name, coordinate: center) {
                    AdventurePin(adventure: adventure)
                }
                .tag(MapDestination.adventure(adventure))
            }
        }
        ForEach(map.placeResults, id: \.self) { item in
            Marker(item: item)
                .tag(MapDestination.place(item))
        }
    }

    /// The adventure's routes as lines and its waypoints as markers. Other routes are dimmed when one is focused.
    @MapContentBuilder
    private func adventureContent(_ adventure: Adventure, focusedRoute: Route?) -> some MapContent {
        ForEach(adventure.routes) { route in
            let isDimmed = focusedRoute != nil && focusedRoute != route
            MapPolyline(coordinates: path(of: route))
                .stroke(isDimmed ? Color.gray.opacity(0.5) : Color.accentColor,
                        style: StrokeStyle(lineWidth: isDimmed ? 3 : 5, lineCap: .round, lineJoin: .round))
        }
        ForEach(adventure.routes.flatMap(\.orderedWaypoints)) { waypoint in
            let isDimmed = focusedRoute != nil && focusedRoute != waypoint.route
            Marker(waypoint.name, systemImage: waypoint.icon, coordinate: waypoint.coordinate)
                .tint(isDimmed ? .gray : waypoint.isChecked ? .green : .accentColor)
                .tag(MapDestination.waypoint(waypoint))
        }
    }

    /// The route's path, joined from each leg's. See `PointLeg.pathCoordinates`.
    private func path(of route: Route) -> [CLLocationCoordinate2D] {
        let legs = route.orderedPointLegs
        guard !legs.isEmpty else { return route.orderedWaypoints.map(\.coordinate) }
        return legs.flatMap(\.pathCoordinates)
    }
}

/// An adventure's cover in a rounded frame, used as its pin on the map.
private struct AdventurePin: View {
    let adventure: Adventure

    var body: some View {
        Group {
            if let image = UIImage(data: adventure.image) {
                Image(uiImage: image)
                    .thumbnailStyle(width: 36, height: 48, cornerRadius: 6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 48)
                    .overlay {
                        Image(systemName: "map")
                            .foregroundStyle(.white)
                    }
            }
        }
        .padding(3)
        .background(.white, in: .rect(cornerRadius: 9))
        .shadow(radius: 3, y: 1)
    }
}

#Preview {
    MapScreen()
        .modelContainer(SampleData.shared.modelContainer)
}
