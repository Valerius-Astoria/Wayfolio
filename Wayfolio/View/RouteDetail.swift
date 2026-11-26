//
//  RouteDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI

/// A route's detail page: its introduction and a timeline of its waypoints.
struct RouteDetail: View {
    /// Owned here rather than read from the environment, because this view is the one that sets it.
    @State private var editMode: EditMode = .inactive
    @State private var isAddingWaypoint = false
    
    @Bindable var route: Route
    private var isEditing: Bool { editMode.isEditing }
    
    var body: some View {
        List {
            if isEditing {
                Section("Details") {
                    TextField("Name", text: $route.name)
                    TextField("Brief", text: $route.brief.orEmpty, axis: .vertical)
                        .lineLimit(1...)
                    // One past the last day, so the route can start a new day.
                    Stepper("Day \(route.day)", value: day, in: 1...(route.adventure.dayCount + 1))
                    Picker("Default Transport", selection: $route.defaultTransportType) {
                        ForEach(TransportType.allCases, id: \.self) { type in
                            Label(type.label.name, systemImage: type.label.icon)
                        }
                    }
                }
            }
            if isEditing || route.intro != nil {
                Section("Introduction") {
                    TextField("Intro", text: $route.intro.orEmpty, axis: .vertical)
                }
            }
            Section("Schedule") {
                Timeline(route: route)
                if isEditing {
                    AddItemButton("Add Waypoint") { isAddingWaypoint = true }
                }
            }
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $isAddingWaypoint) {
            AddWaypointSheet(route: route)
        }
        .task(id: route.pointLegs) {
            await route.loadMissingDirections()
        }
    }

    /// A binding to the route's day that moves it to the end of the new day.
    private var day: Binding<Int> {
        Binding(
            get: { route.day },
            set: { newDay in
                guard newDay != route.day else { return }
                route.order = route.adventure.routes(on: newDay).count
                route.day = newDay
            }
        )
    }
}

/// A vertical timeline of a route: each waypoint at its start time,
/// connected by lines that show how to travel each leg.
///
/// Produces one list row per waypoint and per leg, so place it directly inside a `List` or `Section`.
struct Timeline: View {
    @Environment(\.editMode) private var editMode

    let route: Route
    
    /// The width of the time column. The connecting lines run down its center.
    private let timeColumnWidth: CGFloat = 44
    
    var body: some View {
        // Two separate `ForEach`es rather than one that hides the legs: if the number of rows per waypoint
        // changed in place, the list would attach the edit controls to the wrong rows.
        if editMode?.wrappedValue.isEditing == true {
            // Legs are left out, because they're rebuilt on every move and would otherwise be dragged with their waypoint.
            ForEach(route.orderedWaypoints, id: \.self) { waypoint in
                waypointLink(waypoint)
            }
            .onDelete(perform: route.deleteWaypoints)
            .onMove(perform: route.moveWaypoints)
        } else {
            ForEach(route.orderedWaypoints, id: \.self) { waypoint in
                waypointLink(waypoint)

                if let leg = route.leg(from: waypoint) {
                    legRow(leg)
                        .timelineRow()
                        .deleteDisabled(true)
                }
            }
            .onDelete(perform: route.deleteWaypoints)
        }
    }

    private func waypointLink(_ waypoint: Waypoint) -> some View {
        NavigationLink(value: MapDestination.waypoint(waypoint)) {
            waypointRow(waypoint)
        }
        .timelineRow()
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
                Label("\(waypoint.clues.count { $0.isChecked })/\(waypoint.clues.count)", systemImage: "scroll")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(waypoint.clues.count { $0.isChecked }) of \(waypoint.clues.count) clues checked")
            }
        }
        .padding(.vertical, 6)
    }
    
    /// A line with the transport symbol in the middle, followed by the travel time and distance.
    private func legRow(_ leg: PointLeg) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                connectorLine
                Image(systemName: leg.transportType.label.icon)
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
    RouteDetail(route: Adventure.sampleData.first!.routes.first!)
        .previewInMapStack()
}
