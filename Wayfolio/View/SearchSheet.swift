//
//  SearchSheet.swift
//  Wayfolio
//
//  Created by ZAKA on 11/22/26.
//

import SwiftUI
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
                    AdventureRow(adventure: adventure)
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
    
    var body: some View {
        HStack {
            if let uiImage = UIImage(data: adventure.image) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 72)
                        .clipShape(.rect(cornerRadius: 8))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "map")
                }
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text(adventure.name).font(.headline)
                        .padding(.trailing)
                    Text(adventure.brief).font(.subheadline).foregroundStyle(.gray)
                }
                
                HStack {
                    Text("\(adventure.routes.count) routes · \(adventure.waypointCount) places · \(adventure.dayCount) days")
                        .padding(.trailing)
                    ForEach(adventure.types.sorted(), id: \.self) { type in
                        Image(systemName: type.label.icon)
                            .foregroundStyle(type.label.color)
                    }
                }
                .font(.caption)
                .bold()
            }
        }
        
    }
}

#Preview {
    SearchSheet()
        .modelContainer(SampleData.shared.modelContainer)
}
