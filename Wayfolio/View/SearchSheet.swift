//
//  SearchSheet.swift
//  Wayfolio
//
//  Created by ZAKA on 11/22/26.
//

import SwiftUI
import PhotosUI
import SwiftData

/// Lists all adventures and filters them as the user types. See `Adventure.search(query:in:)`.
struct SearchSheet: View {
    @Query(sort: \Adventure.name) private var adventures: [Adventure]
    
    @State private var query = ""
    
    var body: some View {
        NavigationStack {
            List(Adventure.search(query: query, in: adventures)) { adventure in
                NavigationLink {
                    AdventureDetail(adventure: adventure)
                } label: {
                    AdventureRow(adventure: adventure, font: .caption.bold())
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search adventures")
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
                    if let uiImage = UIImage(data: adventure.image) {
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
                    }
                }
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
}
