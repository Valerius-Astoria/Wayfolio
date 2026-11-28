//
//  MaoView.swift
//  Wayfolio
//
//  Created by ZAKA on 11/27/26.
//

import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @State private var isSheetPresented = true
    @State private var detent: PresentationDetent = .medium
    
    @Bindable var mapModel: MapModel

    private let locationManager = CLLocationManager()

    var body: some View {
        GeometryReader { proxy in
            Map(position: $mapModel.cameraPosition, selection: $mapModel.selectedWaypoint) {
                // Display user location.
                UserAnnotation()
                // Display waypoints on the current routes, numbered by visit order.
                ForEach(mapModel.visibleWaypoints, id: \.persistentModelID) { waypoint in
                    Marker(
                        waypoint.name,
                        monogram: Text("\(waypoint.order + 1)"),
                        coordinate: waypoint.coordinate
                    )
                    .tint(mapModel.color(for: waypoint.route))
                    .tag(waypoint)
                }
                // Display routes.
                ForEach(mapModel.drawnRoutes) { drawn in
                    ForEach(drawn.officialPaths, id: \.self) { path in
                        MapPolyline(path)
                            .stroke(drawn.color, lineWidth: 5)
                    }
                    ForEach(Array(drawn.customPaths.enumerated()), id: \.offset) { _, coordinates in
                        if coordinates.count >= 2 {
                            MapPolyline(coordinates: coordinates)
                                .stroke(drawn.color, lineWidth: 5)
                        }
                    }
                }
            }
            .task(id: mapModel.directionsFingerprint) {
                await mapModel.loadDirectionsForSelection()
            }
            // Shifts the camera's center point, legal label, and controls up into the visible area
            .safeAreaPadding(.bottom, bottomPadding(for: proxy.size.height))
            .animation(.easeInOut(duration: 0.25), value: detent)
            .mapControls {
                MapUserLocationButton()
            }
            .onAppear {
                locationManager.requestWhenInUseAuthorization()
            }
            .onChange(of: mapModel.selectedWaypoint) { _, waypoint in
                guard let waypoint else { return }
                mapModel.focusCamera(on: waypoint)
                mapModel.revealInSheet(waypoint)
            }
            .onChange(of: mapModel.navigationPath.count) { oldCount, newCount in
                mapModel.handleNavigationPop(from: oldCount, to: newCount)
            }
            .sheet(isPresented: $isSheetPresented) {
                SearchSheet()
                    .presentationDetents([.fraction(0.15), .medium, .large], selection: $detent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .interactiveDismissDisabled()
                    .environment(mapModel)
            }
        }
    }

    /// Matches the sheet's visible height so the camera stays centered in the uncovered portion.
    private func bottomPadding(for totalHeight: CGFloat) -> CGFloat {
        switch detent {
        case .fraction(0.15):
            return totalHeight * 0.15
        case .medium:
            return totalHeight * 0.5
        default:
            // When .large is active, keep the .medium offset so the camera doesn't jump wildly
            return totalHeight * 0.5
        }
    }
}


#Preview {
    MapView(mapModel: MapModel())
}
