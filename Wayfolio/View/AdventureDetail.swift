//
//  AdventureDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI
import SwiftData
import PhotosUI

/// An adventure's detail page: a header with the cover, name, and size,
/// followed by its introduction, routes, and notes.
struct AdventureDetail: View {
    @Environment(MapModel.self) private var map
    /// Owned here rather than read from the environment, because this view is the one that sets it.
    @State private var editMode: EditMode = .inactive
    /// The day whose routes are listed, or `nil` for all days.
    @State private var day: Int?
    /// The days whose routes are hidden under their "Day" subtitle. Ignored while editing.
    @State private var collapsedDays: Set<Int> = []
    @State private var isAddingRoute = false
    @State private var isAddingNote = false
    @State private var newTag = ""
    @State private var coverPhoto: PhotosPickerItem?
    
    @Bindable var adventure: Adventure
    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        VStack(alignment: .leading) {
            AdventureRow(adventure: adventure, imageWidth: 84, imageHeight: 112, font: .footnote)
                .padding(.horizontal)
            
            List() {
                // MARK: Details
                if isEditing {
                    Section("Details") {
                        TextField("Name", text: $adventure.name)
                        TextField("Brief", text: $adventure.brief.orEmpty, axis: .vertical)
                            .lineLimit(1...)
                        TextField("Region", text: $adventure.region)
                        PhotosPicker(selection: $coverPhoto, matching: .images) {
                            Label("Change Cover", systemImage: "photo")
                        }
                        AdventureTypePicker(selection: $adventure.types)
                        tagEditor
                    }
                }

                // MARK: Introduction
                Section("Introduction") {
                    if isEditing {
                        TextField("Intro", text: $adventure.intro, axis: .vertical)
                            .lineLimit(1...)
                    } else {
                        ExpandableText(adventure.intro)
                    }
                    
                }
                
                // MARK: Routes
                Section {
                    // One flat `ForEach`, so routes can be dragged under another day's header.
                    ForEach(routeRows, id: \.self) { row in
                        switch row {
                        case .day(let day):
                            dayHeader(day)
                                .moveDisabled(true)
                                .deleteDisabled(true)
                        case .route(let route):
                            Button {
                                map.path.append(.route(route))
                            } label: {
                                RouteRow(route: route)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                    }
                    .onMove(perform: moveRoutes)
                    .onDelete { offsets in
                        let rows = routeRows
                        adventure.delete(offsets.compactMap { rows[$0].route })
                    }

                    if isEditing {
                        AddItemButton("Add Route") { isAddingRoute = true }
                    }
                } header: {
                    HStack {
                        Text("Routes")
                        Spacer()
                        dayPicker
                    }
                }
                
                // MARK: Good to Know
                Section("Good to Know") {
                    ForEach($adventure.notes) { $note in
                        Group {
                            if isEditing {
                                noteEditor($note)
                            } else {
                                Label(note.body, systemImage: note.icon)
                            }
                        }
                        .font(.subheadline)
                        .listRowBackground(Color.clear)
                    }
                    .onMove(perform: adventure.moveNotes)
                    .onDelete(perform: adventure.deleteNotes(at:))

                    if isEditing {
                        AddItemButton("Add Note") { isAddingNote = true }
                    }
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                if !isEditing {
                    AdventureActionButton(adventure: adventure)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: isEditing)
            .toolbar {
                EditButton()
            }
            .sheet(isPresented: $isAddingRoute) {
                AddRouteSheet(adventure: adventure, day: day ?? adventure.days.last ?? 1)
            }
            .sheet(isPresented: $isAddingNote) {
                AddNoteSheet(adventure: adventure)
            }
        }
        .environment(\.editMode, $editMode)
        .task(id: coverPhoto) {
            guard let data = try? await coverPhoto?.loadTransferable(type: Data.self),
                  let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.8) else { return }
            adventure.image = jpeg
            coverPhoto = nil
        }
    }

    /// The day picked in `dayPicker`, or every day with routes if it's All Days.
    var visibleDays: [Int] {
        day.map { [$0] } ?? adventure.days
    }

    // MARK: - Routes

    /// A row in the Routes section: a day's header or one of its routes.
    private enum RouteListRow: Hashable {
        case day(Int)
        case route(Route)

        var route: Route? {
            if case .route(let route) = self { route } else { nil }
        }
    }

    /// Each visible day's header followed by its routes, unless the day is collapsed.
    private var routeRows: [RouteListRow] {
        visibleDays.flatMap { day -> [RouteListRow] in
            let routes = isEditing || !collapsedDays.contains(day) ? adventure.routes(on: day) : []
            return [.day(day)] + routes.map { .route($0) }
        }
    }

    /// Moves routes in `routeRows`, putting each route on the day of the nearest header above it.
    ///
    /// A route dropped above the first header joins that first day.
    private func moveRoutes(from source: IndexSet, to destination: Int) {
        var rows = routeRows
        rows.move(fromOffsets: source, toOffset: destination)

        var groups: [(day: Int, routes: [Route])] = []
        for row in rows {
            switch row {
            case .day(let day):
                if groups.last?.day != day {
                    groups.append((day, []))
                }
            case .route(let route):
                if groups.isEmpty {
                    groups.append((visibleDays.first ?? route.day, []))
                }
                groups[groups.count - 1].routes.append(route)
            }
        }
        for group in groups {
            adventure.arrange(group.routes, on: group.day)
        }
    }
    
    /// A menu that filters the routes to one day, or shows all of them.
    private var dayPicker: some View {
        Menu {
            Picker("Day", selection: $day) {
                Text("All Days").tag(Int?.none)
                ForEach(adventure.days, id: \.self) { day in
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
    
    /// A "Day" subtitle that shows or hides the routes on `day`. Every day stays expanded while editing.
    private func dayHeader(_ day: Int) -> some View {
        let isExpanded = isEditing || !collapsedDays.contains(day)
        return Button {
            guard !isEditing else { return }
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
                if !isEditing {
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }

    // MARK: - Editing

    /// The adventure's tags as removable chips, and a field for adding one. Search matches the tags.
    private var tagEditor: some View {
        VStack(alignment: .leading) {
            if !adventure.tags.isEmpty {
                FlowLayout {
                    ForEach(adventure.tags, id: \.self) { tag in
                        Button {
                            withAnimation(.snappy) { adventure.tags.removeAll { $0 == tag } }
                        } label: {
                            Label(tag, systemImage: "xmark")
                                .labelStyle(TrailingIconLabelStyle())
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5), in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(tag)")
                    }
                }
            }
            TextField("Add Tag", text: $newTag)
                .onSubmit(addTag)
                .submitLabel(.done)
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        newTag = ""
        guard !tag.isEmpty, !adventure.tags.contains(tag) else { return }
        withAnimation(.snappy) { adventure.tags.append(tag) }
    }

    /// An icon menu and a text field for editing `note` in place.
    private func noteEditor(_ note: Binding<Note>) -> some View {
        HStack {
            IconMenu(selection: note.icon, choices: Note.iconChoices)
            TextField("Note", text: note.body, axis: .vertical)
                .lineLimit(1...)
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
            Text("\(route.checkedWaypointCount)/\(route.waypoints.count)")
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
    AdventureDetail(adventure: Adventure.createSampleAdventure())
        .previewInMapStack()
}
