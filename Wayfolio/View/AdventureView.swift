//
//  AdventureView.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import CoreLocation

struct AdventureView: View {
    var adventure: Adventure

    var body: some View {
        VStack(alignment: .leading) {
            List {
                Section {
                    VStack(alignment: .leading) {
                        Text(adventure.name).font(.largeTitle)
                        Text(adventure.brief).font(.callout)
                    }
                    .padding(.bottom)

                    HStack {
                        Spacer()
                        Text("\(adventure.dayCount) days")
                        Text(" ·\(adventure.status.rawValue)")
                    }
                }

                Section("Introduction") {
                    Text(adventure.intro)
                }

                ForEach(adventure.days, id: \.self) { day in
                    Section("Day \(day)") {
                        ForEach(adventure.waypoints(on: day)) { waypoint in
                            WaypointRow(waypoint: waypoint)
                            if let leg = adventure.leg(from: waypoint) {
                                LegRow(leg: leg)
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    ForEach(adventure.notes) { note in
                        Label(note.body, systemImage: note.icon)
                    }
                }
                
                HStack {
                    Spacer()
                    Button("Start Adventure") {}
                    Spacer()
                }
            }
        }
    }
}

private struct WaypointRow: View {
    let waypoint: Waypoint

    var body: some View {
        HStack {
            Label(waypoint.name, systemImage: waypoint.icon)
            Spacer()
            Text("\(format(waypoint.schedule.start)) – \(format(waypoint.schedule.end))")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func format(_ components: DateComponents) -> String {
        guard let date = Calendar.current.date(bySettingHour: components.hour ?? 0,
                                               minute: components.minute ?? 0,
                                               second: 0,
                                               of: .now) else { return "--:--" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct LegRow: View {
    let leg: PointLeg

    @State private var isLoading = false

    var body: some View {
        HStack {
            Label(leg.transportType.label, systemImage: leg.transportType.systemImage)
            Spacer()
            if isLoading {
                ProgressView()
            } else if let time = leg.expectedTravelTime, let distance = leg.distance {
                Text("\(formatTime(time)) · \(formatDistance(distance))")
                    .monospacedDigit()
            } else {
                Text("Unavailable")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.leading)
        .task {
            // Custom routes already store their estimate; official ones are fetched once and cached on the leg.
            guard !leg.useCustomRoute, leg.expectedTravelTime == nil || leg.distance == nil else { return }
            isLoading = true
            _ = try? await leg.getOfficialDirections()
            isLoading = false
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

#Preview {
    AdventureView(adventure: Adventure.sampleData.first!)
}
