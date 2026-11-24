//
//  AdventureDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI

/// An adventure's detail page: a header with the cover, name, and size,
/// followed by its introduction, routes, and notes.
struct AdventureDetail: View {
    let adventure: Adventure
    
    @State private var selectedRoute: Route?

    var body: some View {
        VStack(alignment: .leading) {
            AdventureRow(adventure: adventure, imageWidth: 84, imageHeight: 112, font: .footnote)
                .padding(.horizontal)
            
            List {
                Section("Introduction") {
                    ExpandableText(adventure.intro)
                }
                Section("Routes") {
                    VStack {
                        ForEach(adventure.routes, id: \.self) { route in
                            Button {
                                selectedRoute = route
                            } label: {
                                RouteRow(route: route)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Attention") {
                    ForEach(adventure.notes) { note in
                        Label(note.body, systemImage: note.icon)
                            .font(.subheadline)
                    }
                }
            }
            .listStyle(.plain)
            .navigationDestination(item: $selectedRoute) { route in
                RouteDetail(route: route)
            }
        }
    }
}

/// A card showing a route's name, time span, brief, and how many of its waypoints are checked.
struct RouteRow: View {
    let route: Route
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(route.name).font(.headline)
                    Text("(\(route.schedule.display()))").font(.subheadline)
                }
                if let brief = route.brief {
                    Text(brief).font(.subheadline)
                }
            }
            Spacer()
            Text("\(route.waypoints.count { $0.isChecked }) / \(route.waypoints.count)")
                .font(.footnote)
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
        )
    }
}

#Preview {
    NavigationStack {
        AdventureDetail(adventure: Adventure.createSampleAdventure())
    }
}
