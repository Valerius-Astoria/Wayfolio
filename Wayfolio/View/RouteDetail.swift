//
//  RouteDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI

/// A route's detail page: its introduction and a timeline of its waypoints.
struct RouteDetail: View {
    let route: Route
    
    var body: some View {
        List {
            Section("Introduction") {
                ExpandableText(route.intro)
            }
            Section("Schedule") {
                Timeline(route: route)
            }
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0) // Lets the leg rows be shorter than a normal row.
    }
}

/// A vertical timeline of a route: each waypoint at its start time,
/// connected by lines that show how to travel each leg.
///
/// Produces one list row per waypoint and per leg, so place it directly inside a `List` or `Section`.
struct Timeline: View {
    let route: Route
    
    /// The width of the time column. The connecting lines run down its center.
    private let timeColumnWidth: CGFloat = 44
    
    var body: some View {
        ForEach(route.orderedWaypoints, id: \.self) { waypoint in
            NavigationLink {
                Text("Waypoint Detail")
            } label: {
                waypointRow(waypoint)
            }
            .timelineRow()
            
            if let leg = route.leg(from: waypoint) {
                legRow(leg)
                    .timelineRow()
            }
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
        }
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
            
            Text(travelSummary(of: leg))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var connectorLine: some View {
        Rectangle()
            .fill(.gray.opacity(0.4))
            .frame(width: 2, height: 14)
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
        return parts.isEmpty ? leg.transportType.label : parts.joined(separator: " · ")
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
    
}
