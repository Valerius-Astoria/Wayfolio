//
//  SearchSheet.swift
//  Wayfolio
//
//  Created by ZAKA on 11/22/26.
//

import SwiftUI
import SwiftData
import MapKit

/// The sheet over the map: a search bar that finds adventures and Apple Maps places,
/// and the navigation stack for every page opened from it.
///
/// Opening a page pushes a `MapDestination` onto `MapModel.path`, which also moves the map.
struct SearchSheet: View {
    @Environment(MapModel.self) private var map
    @Query(sort: \Adventure.name) private var adventures: [Adventure]

    @State private var query = ""
    @State private var filter = SearchFilter()
    @State private var isSearchingPlaces = false
    @State private var isFiltering = false
    @State private var isAddingAdventure = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        @Bindable var map = map
        NavigationStack(path: $map.path) {
            List {
                if filter.showsAdventures, !adventureResults.isEmpty {
                    Section("Adventures") {
                        ForEach(adventureResults) { adventure in
                            NavigationLink(value: MapDestination.adventure(adventure)) {
                                AdventureRow(adventure: adventure, font: .caption.bold())
                            }
                        }
                    }
                }
                if filter.showsPlaces, !map.placeResults.isEmpty {
                    Section("Places") {
                        ForEach(map.placeResults, id: \.self) { item in
                            NavigationLink(value: MapDestination.place(item)) {
                                PlaceRow(item: item)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if hasNoResults {
                    ContentUnavailableView.search(text: query)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                searchBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .mapDestinations()
        }
        .task(id: PlaceQuery(text: query, categories: filter.categories, isEnabled: filter.showsPlaces)) {
            await searchPlaces()
        }
        .onChange(of: isSearchFieldFocused) {
            // Typing needs room for the keyboard and the results.
            if isSearchFieldFocused {
                map.detent = .large
            }
        }
        .sheet(isPresented: $isFiltering) {
            FilterSheet(filter: $filter)
        }
        .sheet(isPresented: $isAddingAdventure) {
            AddAdventureSheet { adventure in
                map.path.append(.adventure(adventure))
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Adventures and places", text: $query)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if isSearchingPlaces {
                    ProgressView()
                } else if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .glassEffect(in: .capsule)

            Button {
                isFiltering = true
            } label: {
                Image(systemName: filter.isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .foregroundStyle(filter.isActive ? Color.accentColor : .primary)
            .glassEffect(in: .circle)
            .accessibilityLabel("Filter")
            .accessibilityValue(filter.isActive ? "On" : "Off")

            Button {
                isAddingAdventure = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(in: .circle)
            .accessibilityLabel("New Adventure")
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Results

    /// The adventures that match the query and the filter.
    private var adventureResults: [Adventure] {
        Adventure.search(query: query, in: adventures).filter(filter.matches)
    }

    private var hasNoResults: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSearchingPlaces
            && (!filter.showsAdventures || adventureResults.isEmpty)
            && (!filter.showsPlaces || map.placeResults.isEmpty)
    }

    /// What a place search depends on, so it reruns only when one of these changes.
    private struct PlaceQuery: Equatable {
        var text: String
        var categories: Set<MKPointOfInterestCategory>
        var isEnabled: Bool
    }

    /// Searches Apple Maps around the visible part of the map, after a short pause in typing.
    private func searchPlaces() async {
        guard filter.showsPlaces else {
            map.placeResults = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        isSearchingPlaces = true
        defer { isSearchingPlaces = false }
        let results = await PlaceSearch.search(query: query, categories: filter.categories, region: map.visibleRegion)
        guard !Task.isCancelled else { return }
        map.placeResults = results
    }
}

/// A search result from Apple Maps: its category icon, name, and address.
private struct PlaceRow: View {
    let item: MKMapItem

    var body: some View {
        let label = (item.pointOfInterestCategory ?? .landmark).label
        HStack(spacing: 12) {
            Image(systemName: label.icon)
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(label.color.gradient, in: .circle)
            VStack(alignment: .leading) {
                Text(item.name ?? "Unnamed")
                    .font(.subheadline.bold())
                if let address = item.address?.shortAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A list row showing an adventure's name, brief, size, and type icons.
struct AdventureRow: View {
    let adventure: Adventure
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let font: Font
    
    init(adventure: Adventure, imageWidth: CGFloat = 54, imageHeight: CGFloat = 72, font: Font) {
        self.adventure = adventure
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.font = font
    }
    
    var body: some View {
        HStack(alignment: .bottom) {
            if let uiImage = UIImage(data: adventure.image) {
                Image(uiImage: uiImage)
                    .thumbnailStyle(width: imageWidth, height: imageHeight)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 53, height: 72)
            }
            VStack(alignment: .leading) {
                Text(adventure.name).font(.headline)
                if let brief = adventure.brief {
                    Text(brief).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    Text("\(adventure.routes.count) routes · \(adventure.waypointCount) places · \(adventure.dayCount) days")
                        .padding(.trailing)
                    ForEach(adventure.types.sorted(), id: \.self) { type in
                        Image(systemName: type.label.icon)
                            .foregroundStyle(type.label.color)
                    }
                }
                .font(font)
            }
        }
        
    }
}

#Preview {
    SearchSheet()
        .modelContainer(SampleData.shared.modelContainer)
        .environment(MapModel())
}
