//
//  RouteDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI
import SwiftData
import MapKit

/// A route's detail page: its introduction and a timeline of its waypoints.
struct RouteDetail: View {
    @Environment(MapModel.self) var mapModel
    @State private var placeQuery = ""
    @State private var isPlaceSearchPresented = false
    
    @Bindable var route: Route
    
    private var isEditing: Bool { mapModel.isEditingRoute }
    
    var body: some View {
        @Bindable var mapModel = mapModel
        Group {
            if isEditing {
                Group {
                    RouteDetailList(route: route, placeQuery: $placeQuery, isPlaceSearchPresented: $isPlaceSearchPresented)
                }
                .searchable(text: $placeQuery, isPresented: $isPlaceSearchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search places")
            } else {
                RouteDetailList(route: route, placeQuery: $placeQuery, isPlaceSearchPresented: $isPlaceSearchPresented)
            }
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $mapModel.routeEditMode)
        .onChange(of: placeQuery) { _, query in
            guard isEditing else { return }
            mapModel.searchPlaces(query)
        }
        .onChange(of: isEditing) { _, editing in
            if !editing {
                placeQuery = ""
                isPlaceSearchPresented = false
                mapModel.searchPlaces("")
                mapModel.highlightedPlace = nil
            }
        }
        .onChange(of: mapModel.selectedPOI != nil) { _, showingPOI in
            guard showingPOI else { return }
            placeQuery = ""
            isPlaceSearchPresented = false
            mapModel.searchPlaces("")
        }
        .task(id: waypointGraphID) {
            route.rebuildLegs()
            for pointLeg in route.orderedPointlegs where pointLeg.distance == nil && !pointLeg.useCustomRoute {
                if Task.isCancelled { return }
                _ = try? await pointLeg.getOfficialDirections()
            }
        }
    }

    /// Waypoint identity, visit order, and coordinates — any change means the legs are stale.
    private var waypointGraphID: String {
        route.orderedWaypoints
            .map { "\($0.persistentModelID):\($0.order):\($0.latitude):\($0.longitude)" }
            .joined(separator: "|")
    }
}

/// The route's list. Hides title fields while the place-search field is active.
private struct RouteDetailList: View {
    @Bindable var route: Route
    @Binding var placeQuery: String
    @Binding var isPlaceSearchPresented: Bool

    @Environment(MapModel.self) private var mapModel
    @FocusState private var isTextFieldFocused: Bool

    private var isEditing: Bool { mapModel.isEditingRoute }

    var body: some View {
        List {
            if isEditing, !isPlaceSearchPresented {
                HStack {
                    Text("Title").padding(.trailing, 5)
                    TextField(route.name, text: $route.name)
                        .foregroundStyle(.secondary)
                        .focused($isTextFieldFocused)
                }
                HStack {
                    Text("Subtitle").padding(.trailing, 5)
                    TextField("Intro", text: $route.brief.orEmpty, axis: .vertical)
                        .foregroundStyle(.secondary)
                        .focused($isTextFieldFocused)
                }
            }
            if !isPlaceSearchPresented, isEditing || route.intro != nil {
                Section("Introduction") {
                    TextField("Intro", text: $route.intro.orEmpty, axis: .vertical)
                }
            }
            if isEditing, !mapModel.placeCompletions.isEmpty {
                Section("Places") {
                    ForEach(mapModel.placeCompletions, id: \.self) { completion in
                        Button {
                            Task {
                                await mapModel.selectPlace(completion)
                                placeQuery = ""
                                isPlaceSearchPresented = false
                                mapModel.searchPlaces("")
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(completion.title)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            Section("Schedule") {
                if route.orderedWaypoints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No places yet")
                        Text("Select a place on the map, or search for one in the editor, to add it to this route.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Timeline(route: route)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
    }
}

/// A vertical timeline of a route: each waypoint at its start time,
/// connected by lines that show how to travel each leg.
///
/// Produces one list row per waypoint and per leg, so place it directly inside a `List` or `Section`.
struct Timeline: View {
    let route: Route
    
    @Environment(MapModel.self) var mapModel
    @Environment(\.editMode) private var editMode
    
    private var isEditing: Bool { editMode?.wrappedValue.isEditing ?? false }
    
    /// The width of the time column. The connecting lines run down its center.
    private let timeColumnWidth: CGFloat = 44
    
    var body: some View {
        ForEach(route.orderedWaypoints, id: \.persistentModelID) { waypoint in
            waypointLine(waypoint)
                .timelineRow()
            
            if let leg = route.leg(from: waypoint) {
                legRow(leg)
                    .timelineRow()
                    .deleteDisabled(true)
                    .moveDisabled(true)
            }
        }
        .onDelete(perform: route.deleteWaypoints)
        .onMove(perform: route.moveWaypoints)
    }
    
    @ViewBuilder
    private func waypointLine(_ waypoint: Waypoint) -> some View {
        if isEditing {
            waypointRow(waypoint)
        } else {
            Button {
                mapModel.select(waypoint)
            } label: {
                waypointRow(waypoint)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func waypointRow(_ waypoint: Waypoint) -> some View {
        HStack(spacing: 12) {
            Text(startTime(of: waypoint.schedule))
                .font(.subheadline.monospacedDigit().bold())
                .frame(width: timeColumnWidth)
            Circle()
                .fill(waypoint.isChecked ? .green : .gray)
                .frame(width: 10, height: 10)
            Text("\(waypoint.name) (\(waypoint.schedule.stayMinutes) min)")
            Spacer()
            if !waypoint.clues.isEmpty {
                Text("📜: \(waypoint.clues.count { $0.isChecked }) / \(waypoint.clues.count)")
                    .font(.footnote)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
    
    /// A line with the transport symbol in the middle, followed by the travel time and distance.
    private func legRow(_ leg: PointLeg) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                connectorLine
                Image(systemName: leg.transportType.systemImage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                connectorLine
            }
            .frame(width: timeColumnWidth)
            
            Menu {
                Picker("Transport", selection: transportType(of: leg)) {
                    ForEach(TransportType.allCases, id: \.self) { type in
                        Label(type.label.name, systemImage: type.label.icon)
                    }
                }
            } label: {
                HStack {
                    Text(travelSummary(of: leg))
                        .font(.caption)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.blue)
            }
        }
    }
    
    private var connectorLine: some View {
        Rectangle()
            .fill(.gray.opacity(0.4))
            .frame(width: 2, height: 14)
    }

    /// A binding to `leg`'s transport type that fetches new directions when it changes,
    /// unless the leg uses a recorded path.
    private func transportType(of leg: PointLeg) -> Binding<TransportType> {
        Binding(
            get: { leg.transportType },
            set: { newType in
                guard newType != leg.transportType else { return }
                leg.transportType = newType
                guard !leg.useCustomRoute else { return }
                Task { _ = try? await leg.getOfficialDirections() }
            }
        )
    }

    /// The start time, such as `"9:05"`.
    private func startTime(of schedule: Schedule) -> String {
        String(format: "%d:%02d", schedule.startHour, schedule.startMinute)
    }
    
    /// The travel time and distance, such as `"12 min · 850 m"`. Leaves out whichever is unknown.
    private func travelSummary(of leg: PointLeg) -> String {
        var parts: [String] = []
        if let time = leg.expectedTravelTime {
            parts.append(Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
        }
        if let distance = leg.distance {
            parts.append(Measurement(value: distance, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .road)))
        }
        return (parts.isEmpty ? leg.transportType.label.name : parts.joined(separator: " · "))
    }
}

private extension View {
    /// Removes the separator and vertical padding so consecutive timeline rows join up.
    func timelineRow() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
}

#Preview {
    NavigationStack {
        RouteDetail(route: Adventure.sampleData.first!.routes.first!)
    }
    .environment(MapModel())
}
