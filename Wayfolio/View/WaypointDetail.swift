//
//  WaypointDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI

struct WaypointDetail: View {
    let waypoint: Waypoint
    
    var body: some View {
        HStack {
            VStack {
                Text("Schedule").font(.title3)
                Text(waypoint.schedule.display()).font(.subheadline)
            }
            .padding(.horizontal)
            
            Divider().frame(height: 36)
            
            VStack {
                Text("IsOpen").font(.title3)
                if let isOpening = waypoint.isOpening {
                    Text(isOpening ? "Open" : "Closed")
                        .foregroundStyle(isOpening ? Color.green : .red)
                        .font(.subheadline)
                } else {
                    Text("Unknown")
                        .foregroundStyle(Color.gray)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            
            Divider().frame(height: 36)
            
            VStack {
                Text("Status").font(.title3)
                Text(waypoint.isChecked ? "Checked" : "Unchecked")
                    .foregroundStyle(waypoint.isChecked ? Color.green : .gray)
                    .font(.subheadline)
            }
            .padding(.horizontal)
        }
        List {
            if let intro  = waypoint.intro {
                Section("Introduction") {
                    Text(intro)
                }
            }
            if !waypoint.clues.isEmpty {
                Section("Clues") {
                    ForEach(waypoint.clues, id: \.self) { clue in
                        NavigationLink {
                            ClueDetail(clue: clue)
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    HStack {
                                        if clue.isChecked {
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 9, height: 9)
                                        }
                                        Text(clue.name)
                                        ForEach(clue.icons, id: \.self) { label in
                                            Image(systemName: label.icon)
                                                .foregroundStyle(label.color)
                                                .font(.footnote)
                                        }
                                    }
                                    
                                    if let brief = clue.brief {
                                        Text(brief)
                                            .font(.footnote)
                                            .foregroundStyle(.gray)
                                    }
                                    
                                }
                            } icon: {
                                Image(systemName: clue.icon)
                            }
                        }
                    }
                }
            }
            Section("Hours") {
                if let hours = waypoint.hours {
                    VStack {
                        ForEach(hours.grouped()) { group in
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(group.daysDisplay()): ")
                                Text(group.hoursDisplay())
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(group.isClosed ? .red : .secondary)
                            }
                        }
                    }
                } else {
                    Button("Add Hour") {}
                }
            }
            Section("Details") {
                HStack {
                    Text("Phone").padding(.trailing)
                    Text(waypoint.phoneNumber ?? "Unknown")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Website").padding(.trailing)
                    Text(waypoint.url?.absoluteString ?? "Unknown")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Address").padding(.trailing)
                    if (waypoint.fullAddress != nil) || waypoint.shortAddress != nil {
                        Text(waypoint.fullAddress ?? "" + (waypoint.shortAddress ?? ""))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Unknown")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(waypoint.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WaypointDetail(waypoint: Adventure.sampleData.first!.routes.first!.waypoints.first!)
    }
}
