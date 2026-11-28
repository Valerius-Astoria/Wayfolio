//
//  SearchSheet.swift
//  Wayfolio
//
//  Created by ZAKA on 11/22/26.
//

import SwiftUI
import PhotosUI
import SwiftData
import MapKit

/// Lists all adventures and filters them as the user types. See `Adventure.search(query:in:)`.
struct SearchSheet: View {
    @Query(sort: \Adventure.name) private var adventures: [Adventure]
    
    @State private var query = ""
    @Environment(MapModel.self) var mapModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        @Bindable var mapModel = mapModel
        
        NavigationStack(path: $mapModel.navigationPath) {
            List(Adventure.search(query: query, in: adventures)) { adventure in
                Button {
                    mapModel.select(adventure)
                    mapModel.navigationPath.append(adventure)
                } label: {
                    HStack {
                        AdventureRow(adventure: adventure, font: .caption.bold())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle()) // Makes the entire row tappable
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search adventures")
            .navigationDestination(for: Adventure.self) { adventure in
                AdventureDetail(adventure: adventure)
            }
            .navigationDestination(for: Route.self) { route in
                RouteDetail(route: route)
            }
            .navigationDestination(for: Waypoint.self) { waypoint in
                WaypointDetail(waypoint: waypoint)
            }
            .navigationDestination(for: MKMapItem.self) { item in
                POIDetailView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        modelContext.insert(Adventure(name: "New Adventure", brief: nil, intro: ""))
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "plus")
                    }
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
    let isEditing: Bool
    
    @State private var selectedPhoto: PhotosPickerItem?
    
    init(adventure: Adventure, imageWidth: CGFloat = 54, imageHeight: CGFloat = 72, font: Font, isEditing: Bool = false) {
        self.adventure = adventure
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.font = font
        self.isEditing = isEditing
    }
    
    var body: some View {
        HStack(alignment: .bottom) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let data = adventure.image, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .thumbnailStyle(width: imageWidth, height: imageHeight)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: imageWidth, height: imageHeight)
                    }

                    if isEditing {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.black.opacity(0.6), .white.opacity(0.4))
                    }
                }
            }
            .buttonStyle(.plain)
            .allowsHitTesting(isEditing)
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        adventure.image = data
                        try? adventure.modelContext?.save()
                    }
                }
            }
            
            VStack(alignment: .leading) {
                Text(adventure.name).font(.headline)
                if let brief = adventure.brief {
                    Text(brief).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Spacer()
                        .frame(height: 40)
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
