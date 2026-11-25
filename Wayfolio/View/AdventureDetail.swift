//
//  AdventureDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI
import SwiftData

/// An adventure's detail page: a header with the cover, name, and size,
/// followed by its introduction, routes, and notes.
struct AdventureDetail: View {
    @State private var selectedRoute: Route?
    /// Owned here rather than read from the environment, because this view is the one that sets it.
    @State private var editMode: EditMode = .inactive
    /// The day whose routes are listed, or `nil` for all days.
    @State private var day: Int?
    /// The days whose routes are hidden under their "Day" subtitle.
    @State private var collapsedDays: Set<Int> = []
    
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
                Section {
                    ForEach(visibleDays, id: \.self) { day in
                        dayHeader(day)
                        if !collapsedDays.contains(day) {
                            let dayRoutes = routes(on: day)
                            ForEach(dayRoutes) { route in
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
                            .onDelete { offsets in
                                adventure.delete(offsets.map { dayRoutes[$0] })
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Routes")
                        Spacer()
                        dayPicker
                    }
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

    /// The days that have at least one route, in order.
    private var days: [Int] {
        Set(adventure.routes.map(\.day)).sorted()
    }

    /// The day picked in `dayPicker`, or every day with routes if it's All Days.
    private var visibleDays: [Int] {
        day.map { [$0] } ?? days
    }

    /// The routes on `day`, sorted by start time.
    private func routes(on day: Int) -> [Route] {
        adventure.routes
            .filter { $0.day == day }
            .sorted { $0.schedule.startMinutes < $1.schedule.startMinutes }
    }

    /// A "Day" subtitle that shows or hides the routes on `day`.
    private func dayHeader(_ day: Int) -> some View {
        let isExpanded = !collapsedDays.contains(day)
        return Button {
            withAnimation {
                if isExpanded {
                    collapsedDays.insert(day)
                } else {
                    collapsedDays.remove(day)
                }
            }
        } label: {
            HStack {
                Text("Day \(day)")
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }

    /// A menu that filters the routes to one day, or shows all of them.
    private var dayPicker: some View {
        Menu {
            Picker("Day", selection: $day) {
                Text("All Days").tag(Int?.none)
                ForEach(days, id: \.self) { day in
                    Text("Day \(day)").tag(Int?.some(day))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(day.map { "Day \($0)" } ?? "All Days")
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
            }
            .font(.caption)
            .textCase(nil)
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
