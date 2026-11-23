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
            HStack {
                if let uiImage = UIImage(data: adventure.image) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 120)
                        .clipShape(.rect(cornerRadius: 8))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text(adventure.name).font(.title2).bold()
                    }
                    Text(adventure.brief).font(.subheadline).foregroundStyle(.gray)
                    HStack {
                        Text("\(adventure.routes.count) routes · \(adventure.waypointCount) places · \(adventure.dayCount) days")
                            .padding(.trailing)
                        ForEach(adventure.types.sorted(), id: \.self) { type in
                            Image(systemName: type.label.icon)
                                .foregroundStyle(type.label.color)
                        }
                    }
                    .font(.footnote)
                }
            }
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
                    Text("(\(route.schedule().display()))").font(.subheadline)
                }
                HStack {
                    Text(route.brief)
                    Spacer()
                    Text("🕍: \(route.waypoints.count { $0.isChecked }) / \(route.waypoints.count)")
                        .font(.footnote)
                }
                .font(.subheadline)
            }
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
