//
//  AddItemSheets.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import SwiftUI
import MapKit
import PhotosUI
import SwiftData

// Each sheet asks only for an item's non-optional fields.
// The rest are filled in later from the item's own edit mode.

/// A sheet for adding an adventure.
struct AddAdventureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var region = ""
    @State private var intro = ""
    @State private var types: [AdventureType] = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?

    /// Called with the new adventure after it's saved, such as to open it.
    let onAdd: (Adventure) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            cover
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cover Photo")
                        VStack {
                            TextField("Name", text: $name)
                            Divider()
                            TextField("Region", text: $region)
                        }
                    }
                }
                Section("Introduction") {
                    TextField("Intro", text: $intro, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("Types") {
                    AdventureTypePicker(selection: $types)
                }
            }
            .addSheetToolbar("New Adventure", canAdd: !name.trimmed.isEmpty && !region.trimmed.isEmpty, add: add)
            .task(id: selectedPhoto) {
                guard let data = try? await selectedPhoto?.loadTransferable(type: Data.self) else { return }
                image = UIImage(data: data)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var cover: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .thumbnailStyle(width: 60, height: 80)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 80)
                    .overlay {
                        Image(systemName: "photo.badge.plus")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private func add() {
        let adventure = Adventure(name: name.trimmed,
                                  brief: nil,
                                  intro: intro.trimmed,
                                  types: types,
                                  region: region.trimmed,
                                  tags: [],
                                  // Without a cover, the rows show a placeholder.
                                  image: image?.jpegData(compressionQuality: 0.8) ?? Data())
        modelContext.insert(adventure)
        onAdd(adventure)
    }
}

/// A sheet for adding a route.
struct AddRouteSheet: View {
    @State private var name = ""
    @State private var day: Int
    @State private var transportType: TransportType = .walking

    let adventure: Adventure

    /// - Parameter day: The day the new route starts on.
    init(adventure: Adventure, day: Int) {
        self.adventure = adventure
        _day = State(initialValue: day)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                // One past the last day, so the route can start a new day.
                Stepper("Day \(day)", value: $day, in: 1...(adventure.dayCount + 1))
                Picker("Default Transport", selection: $transportType) {
                    ForEach(TransportType.allCases, id: \.self) { type in
                        Label(type.label.name, systemImage: type.label.icon)
                    }
                }
            }
            .addSheetToolbar("New Route", canAdd: !name.trimmed.isEmpty) {
                adventure.addRoute(name: name.trimmed, day: day, transportType: transportType)
            }
        }
        .presentationDetents([.medium])
    }
}

/// A sheet for adding a note.
struct AddNoteSheet: View {
    @State private var icon = Note.iconChoices[0]
    @State private var text = ""

    let adventure: Adventure

    var body: some View {
        NavigationStack {
            Form {
                TextField("Note", text: $text, axis: .vertical)
                    .lineLimit(1...)
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(Note.iconChoices, id: \.self) { choice in
                            Button {
                                icon = choice
                            } label: {
                                Image(systemName: choice)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(icon == choice ? .white : .primary)
                                    .background(icon == choice ? Color.accentColor : Color(.systemGray6),
                                                in: .rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(choice)
                            .accessibilityAddTraits(icon == choice ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .addSheetToolbar("New Note", canAdd: !text.trimmed.isEmpty) {
                adventure.addNote(icon: icon, body: text.trimmed)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// A sheet for adding a waypoint, either a place found in Apple Maps or a pin dropped on the map.
struct AddWaypointSheet: View {
    private enum Source: Hashable {
        case search, pin
    }

    @State private var source = Source.search
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedItem: MKMapItem?
    @State private var pin: CLLocationCoordinate2D?
    @State private var camera: MapCameraPosition
    @State private var name = ""
    @State private var icon = "mappin"
    @State private var schedule: Schedule

    let route: Route

    init(route: Route) {
        self.route = route
        _schedule = State(initialValue: route.nextSchedule)
        _camera = State(initialValue: Self.region(around: route).map { .region($0) } ?? .automatic)
    }

    private var hasLocation: Bool {
        switch source {
        case .search: selectedItem != nil
        case .pin: pin != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Location", selection: $source) {
                        Text("Search").tag(Source.search)
                        Text("Drop Pin").tag(Source.pin)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    switch source {
                    case .search: searchRows
                    case .pin: pinMap
                    }
                }

                Section("Details") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Icon")
                        Spacer()
                        IconMenu(selection: $icon, choices: Waypoint.iconChoices)
                    }
                }

                Section("Schedule") {
                    ScheduleEditor(schedule: $schedule)
                }
            }
            .addSheetToolbar("New Waypoint", canAdd: hasLocation && !name.trimmed.isEmpty, add: add)
            .task(id: query) { await search() }
        }
    }

    // MARK: Search

    @ViewBuilder
    private var searchRows: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search Apple Maps", text: $query)
                .autocorrectionDisabled()
            if isSearching {
                ProgressView()
            }
        }
        ForEach(results, id: \.self) { item in
            Button {
                select(item)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name ?? "Unnamed")
                            .foregroundStyle(.primary)
                        if let address = item.address?.shortAddress {
                            Text(address)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if item == selectedItem {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    /// Picks `item`, and takes its name unless the user typed their own.
    private func select(_ item: MKMapItem) {
        if name.trimmed.isEmpty || name == selectedItem?.name {
            name = item.name ?? ""
        }
        selectedItem = item
    }

    /// Searches Apple Maps for `query` near the route, after a short pause in typing.
    private func search() async {
        let query = query.trimmed
        guard !query.isEmpty else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        results = await PlaceSearch.search(query: query, region: Self.region(around: route))
    }

    // MARK: Pin

    private var pinMap: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let pin {
                    Marker(name.trimmed.isEmpty ? "New Waypoint" : name, systemImage: icon, coordinate: pin)
                }
                ForEach(route.orderedWaypoints) { waypoint in
                    Marker(waypoint.name, systemImage: waypoint.icon, coordinate: waypoint.coordinate)
                        .tint(.gray)
                }
            }
            .onTapGesture { point in
                pin = proxy.convert(point, from: .local)
            }
        }
        .frame(height: 280)
        .listRowInsets(EdgeInsets())
        .overlay(alignment: .bottom) {
            if pin == nil {
                Text("Tap the map to drop a pin")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: .capsule)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
    }

    /// A region that fits the waypoints of `route`'s adventure, or `nil` if it has none.
    private static func region(around route: Route) -> MKCoordinateRegion? {
        let waypoints = route.waypoints.isEmpty
            ? route.adventure.routes.flatMap(\.waypoints)
            : route.waypoints
        return MKCoordinateRegion(fitting: waypoints.map(\.coordinate))
    }

    // MARK: Add

    private func add() {
        let order = route.waypoints.count
        let waypoint: Waypoint
        switch source {
        case .search:
            guard let selectedItem else { return }
            waypoint = Waypoint(item: selectedItem, name: name.trimmed, icon: icon, intro: nil,
                                schedule: schedule, order: order, route: route)
        case .pin:
            guard let pin else { return }
            waypoint = Waypoint(name: name.trimmed, icon: icon, schedule: schedule,
                                latitude: pin.latitude, longitude: pin.longitude, order: order, route: route)
            // The custom initializer stores an empty intro, which would show an empty Introduction section.
            waypoint.intro = nil
        }
        route.addWaypoint(waypoint)
    }
}

/// A sheet for adding a clue with no conditions.
struct AddClueSheet: View {
    @State private var name = ""
    @State private var detail = ""
    @State private var icon = "folder"

    let waypoint: Waypoint

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Detail", text: $detail, axis: .vertical)
                    .lineLimit(3...)
                HStack {
                    Text("Icon")
                    Spacer()
                    IconMenu(selection: $icon, choices: Clue.iconChoices)
                }
            }
            .addSheetToolbar("New Clue", canAdd: !name.trimmed.isEmpty && !detail.trimmed.isEmpty) {
                waypoint.addClue(name: name.trimmed, detail: detail.trimmed, icon: icon)
            }
        }
        .presentationDetents([.medium])
    }
}

/// A sheet for adding a question the user has to answer to unlock a clue.
struct AddQuestionSheet: View {
    @State private var question = ""
    @State private var answer = ""
    @State private var hint = ""
    @State private var threshold = 5

    let clue: Clue

    var body: some View {
        NavigationStack {
            Form {
                TextField("Question", text: $question, axis: .vertical)
                TextField("Answer", text: $answer)
                    .autocorrectionDisabled()
                Section {
                    TextField("Hint", text: $hint, axis: .vertical)
                    Stepper("Show after \(threshold) tries", value: $threshold, in: 1...20)
                } footer: {
                    Text("Answers ignore case and surrounding spaces.")
                }
            }
            .addSheetToolbar("New Question", canAdd: !question.trimmed.isEmpty && !answer.trimmed.isEmpty) {
                clue.question = QuestionCondition(question: question.trimmed,
                                                  answer: answer.trimmed,
                                                  hint: hint.trimmed,
                                                  threshold: threshold)
            }
        }
        .presentationDetents([.medium])
    }
}

/// A sheet for adding a reference photo the user has to match to unlock a clue.
struct AddPhotoSheet: View {
    @State private var name = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?

    let clue: Clue

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Section("Reference Photo") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 200)
                        } else {
                            Label("Choose Photo", systemImage: "photo.badge.plus")
                        }
                    }
                }
            }
            .addSheetToolbar("New Photo", canAdd: !name.trimmed.isEmpty && image != nil) {
                guard let image else { return }
                clue.photo = PhotoCondition(name: name.trimmed, reference: image)
            }
            .task(id: selectedPhoto) {
                guard let data = try? await selectedPhoto?.loadTransferable(type: Data.self) else { return }
                image = UIImage(data: data)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Shared

/// Cancel and Add buttons for an add sheet. Both dismiss it.
private struct AddSheetToolbar: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let canAdd: Bool
    let add: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        add()
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
    }
}

private extension View {
    func addSheetToolbar(_ title: LocalizedStringKey, canAdd: Bool, add: @escaping () -> Void) -> some View {
        modifier(AddSheetToolbar(title: title, canAdd: canAdd, add: add))
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Note {
    /// The SF Symbols offered when adding or editing a note.
    static let iconChoices = [
        "info.circle", "exclamationmark.triangle", "bus", "umbrella",
        "fork.knife", "camera", "clock", "ticket",
        "creditcard", "figure.walk", "sun.max", "moon"
    ]
}

extension Waypoint {
    /// The SF Symbols offered when adding or editing a waypoint.
    static let iconChoices = [
        "mappin", "cup.and.saucer", "fork.knife", "storefront",
        "building.columns", "building.2", "mountain.2", "water.waves",
        "tree", "camera", "bed.double", "tram"
    ]
}

extension Clue {
    /// The SF Symbols offered when adding or editing a clue.
    static let iconChoices = [
        "folder", "envelope", "scroll", "number",
        "questionmark.circle", "binoculars", "star", "pawprint",
        "key", "lock", "magnifyingglass", "circle.grid.3x3"
    ]
}

#Preview("Route") {
    AddRouteSheet(adventure: Adventure.createSampleAdventure(), day: 1)
}

#Preview("Note") {
    AddNoteSheet(adventure: Adventure.createSampleAdventure())
}

#Preview("Waypoint") {
    AddWaypointSheet(route: Adventure.sampleData.first!.routes.first!)
}

#Preview("Clue") {
    AddClueSheet(waypoint: Adventure.sampleData.first!.routes.first!.orderedWaypoints[0])
}

#Preview("Question") {
    AddQuestionSheet(clue: Adventure.sampleData.first!.routes.first!.orderedWaypoints[0].orderedClues[0])
}
