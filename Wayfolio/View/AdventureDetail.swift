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
    /// Owned here rather than read from the environment, because this view is the one that sets it.
    @State private var editMode: EditMode = .inactive
    /// The day whose routes are listed, or `nil` for all days.
    @State private var day: Int?
    /// The days whose routes are hidden under their "Day" subtitle.
    @State private var collapsedDays: Set<Int> = []
    @State private var selectedTypes: [AdventureType] = []
    
    @Bindable var adventure: Adventure
    @Environment(MapModel.self) var mapModel
    private var isEditing: Bool { editMode.isEditing }
    
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading) {
            AdventureRow(adventure: adventure, imageWidth: 84, imageHeight: 112, font: .footnote, isEditing: isEditing)
                .padding(.horizontal)
            
            List() {
                if isEditing {
                    Section() {
                        HStack {
                            Text("Title").padding(.trailing, 5)
                            TextField("", text: $adventure.name)
                                .foregroundStyle(.secondary)
                                .focused($isTextFieldFocused)
                        }
                        HStack {
                            Text("Subtitle").padding(.trailing, 5)
                            TextField("Intro", text: $adventure.brief.orEmpty, axis: .vertical)
                                .foregroundStyle(.secondary)
                                .focused($isTextFieldFocused)
                        }
                        HStack {
                            Text("Kind").padding(.trailing, 5)
                            ForEach(AdventureType.allCases, id: \.self) { type in
                                let isSelected = adventure.types.contains(type)
                                
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isSelected {
                                            selectedTypes.removeAll { $0 == type }
                                            adventure.types.removeAll { $0 == type }
                                        } else {
                                            selectedTypes.append(type)
                                            adventure.types.append(type)
                                        }
                                    }
                                } label: {
                                    Text(type.label.name)
                                        .font(.footnote)
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .foregroundStyle(isSelected ? .white : type.label.color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            type.label.color.opacity(isSelected ? 0.85 : 0.2),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .onAppear {
                                selectedTypes = adventure.types
                            }
                        }
                        
                    }
                }
                Section("Introduction") {
                    if isEditing {
                        TextField("Intro", text: $adventure.intro, axis: .vertical)
                            .lineLimit(1...)
                            .focused($isTextFieldFocused)
                    } else {
                        ExpandableText(adventure.intro)
                    }
                    
                }
                Section {
                    let rows = routeListRows
                    if isEditing {
                        ForEach(rows) { row in
                            routeRow(row)
                        }
                        .onDelete { offsets in
                            let doomed = offsets.compactMap { offset -> Route? in
                                guard rows.indices.contains(offset),
                                      case .route(let route) = rows[offset] else { return nil }
                                return route
                            }
                            adventure.delete(doomed)
                        }
                    } else {
                        ForEach(rows) { row in
                            routeRow(row)
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
                    ForEach($adventure.notes) { $note in
                        HStack {
                            IconMenu(selection: $note.icon, choices: Note.Symbol.allCases)
                                .padding(.trailing, 5)
                                .foregroundStyle(.blue)
                                .disabled(!isEditing)

                            if isEditing {
                                TextField("", text: $note.body, axis: .vertical)
                            } else {
                                Text(note.body)
                            }
                            
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: adventure.deleteNotes(at:))
                    if isEditing {
                        Button {
                            adventure.notes.append(Note(icon: Note.Symbol.others.rawValue, body: "New Attention"))
                        } label: {
                            AddRow("Add a note")
                        }
                        .deleteDisabled(true)
                        .moveDisabled(true)
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
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

    /// The routes on `day`, sorted by `order`.
    private func routes(on day: Int) -> [Route] {
        adventure.routes(on: day)
    }

    /// Headers, routes, and add rows for the Routes section, in list order.
    private var routeListRows: [RouteListRow] {
        visibleDays.flatMap { dayNumber -> [RouteListRow] in
            var rows: [RouteListRow] = [.header(dayNumber)]
            guard !collapsedDays.contains(dayNumber) else { return rows }
            rows.append(contentsOf: routes(on: dayNumber).map(RouteListRow.route))
            if isEditing {
                rows.append(.add(dayNumber))
            }
            return rows
        }
    }

    @ViewBuilder
    private func routeRow(_ row: RouteListRow) -> some View {
        switch row {
        case .header(let dayNumber):
            dayHeader(dayNumber)
                .deleteDisabled(true)
                .moveDisabled(true)
        case .route(let route):
            if isEditing {
                RouteRow(route: route)
                    .routeListRow()
            } else {
                Button {
                    mapModel.select(route)
                    mapModel.navigationPath.append(route)
                } label: {
                    RouteRow(route: route)
                }
                .buttonStyle(.plain)
                .routeListRow()
            }
        case .add(let dayNumber):
            Button {
                withAnimation {
                    adventure.addRoute(on: dayNumber)
                }
            } label: {
                AddRow("Add a route")
            }
            .deleteDisabled(true)
            .moveDisabled(true)
        }
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

/// A row in the Routes section: a day subtitle, a route, or the add control for that day.
private enum RouteListRow: Identifiable {
    case header(Int)
    case route(Route)
    case add(Int)

    var id: String {
        switch self {
        case .header(let day): "header-\(day)"
        case .route(let route): "route-\(ObjectIdentifier(route))"
        case .add(let day): "add-\(day)"
        }
    }
}

private extension View {
    func routeListRow() -> some View {
        listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
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

/// The label for a "+ Add …" row at the end of a list section in edit mode.
/// Wrap it in a `Button` so the row isn't a button inside a button.
struct AddRow: View {
    var title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Label(title, systemImage: "plus.circle.fill")
            .listRowBackground(Color.clear)
    }
}

/// A menu for picking an icon, labeled with the current symbol.
struct IconMenu<Choice: IconPickable>: View {
    @Binding var selection: String
    let choices: [Choice]

    var body: some View {
        Menu {
            Picker("Icon", selection: $selection) {
                ForEach(choices) { choice in
                    Label(choice.title, systemImage: choice.iconName)
                        .tag(choice.iconName)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: selection)
        }
        .accessibilityLabel("Icon")
        .accessibilityValue(choices.first { $0.iconName == selection }?.title ?? selection)
    }
}
//
//#Preview {
//    NavigationStack {
//        AdventureDetail(adventure: Adventure.createSampleAdventure(), mapModel: <#MapModel#>)
//    }
//}
