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
    @State private var selectedRoute: Route?
    /// Owned here rather than read from the environment, because this view is the one that sets it.
    @State private var editMode: EditMode = .inactive
    
    @Bindable var adventure: Adventure
    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        VStack(alignment: .leading) {
            AdventureRow(adventure: adventure, imageWidth: 84, imageHeight: 112, font: .footnote)
                .padding(.horizontal)
            
            List() {
                Section("Introduction") {
                    if isEditing {
                        TextField("Intro", text: $adventure.intro, axis: .vertical)
                            .lineLimit(1...)
                    } else {
                        ExpandableText(adventure.intro)
                    }
                    
                }
                Section("Routes") {
                    ForEach(adventure.routes, id: \.self) { route in
                        Button {
                            selectedRoute = route
                        } label: {
                            RouteRow(route: route)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: adventure.deleteRoutes(at:))
                }
                
                Section("Attention") {
                    ForEach(adventure.notes) { note in
                        Label(note.body, systemImage: note.icon)
                            .font(.subheadline)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: adventure.deleteNotes(at:))
                }
            }
            .listStyle(.plain)
            .navigationDestination(item: $selectedRoute) { route in
                RouteDetail(route: route)
            }
            .toolbar {
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
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
