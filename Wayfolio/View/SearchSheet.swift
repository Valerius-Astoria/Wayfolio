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
        Label {
            VStack(alignment: .leading) {
                Text(adventure.name).font(.headline)
                    .padding(.trailing)
                Text(adventure.brief).font(.caption2).foregroundStyle(.gray)
            }
            
            HStack {
                Text("\(adventure.waypoints.count) places · \(adventure.dayCount) days")
                    .padding(.trailing)
                ForEach(adventure.types.sorted(), id: \.self) { type in
                    Image(systemName: type.label.icon)
                        .foregroundStyle(type.label.color)
                }
            }
            .font(.caption)
            .bold()
        }
        
        icon: {
            if let uiImage = UIImage(data: adventure.image) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 50)
                    .clipShape(.rect(cornerRadius: 8))
                    .accessibilityHidden(true)
            }
        }
    }
}

struct AdventureDetail: View {
    let adventure: Adventure
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if let uiImage = UIImage(data: adventure.image) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 80)
                        .clipShape(.rect(cornerRadius: 8))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text(adventure.name).font(.headline)
                    }
                    Text(adventure.brief).font(.caption2).foregroundStyle(.gray)
                    HStack {
                        Text("\(adventure.waypoints.count) places · \(adventure.dayCount) days")
                            .padding(.trailing)
                        ForEach(adventure.types.sorted(), id: \.self) { type in
                            Image(systemName: type.label.icon)
                                .foregroundStyle(type.label.color)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            
            NavigationStack {
                List {
                    Section("Introduction") {
                        Text(adventure.intro).font(.subheadline)
                    }
                    Section("Schedule") {
                        Timeline(adventure: adventure)
                    }
                    Section("Attention") {
                        ForEach(adventure.notes) { note in
                            Label(note.body, systemImage: note.icon)
                                .font(.subheadline)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        
    }
}

struct Timeline: View {
    let adventure: Adventure
    
    var body: some View {
        WaypointRow(waypoint: adventure.waypoints.first!)
    }
}

struct WaypointRow: View {
    let waypoint: Waypoint
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if let isOpen = waypoint.isOpening() {
                        Circle().fill(isOpen ? Color.green : .red).frame(width: 10, height: 10)
                    }
                    Text(waypoint.name).bold()
                    Text("(6:00-8:00)").font(.caption)
                }
                HStack {
                    Text(waypoint.brief)
                    Spacer()
                    
                    let count = waypoint.clues.count
                    if count >= 0 { // TODO: Switch to `count > 0` after testing.
                        Text("📜: \(waypoint.clues.count) / \(waypoint.clues.count { $0.isChecked == true})")
                    }
                }
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

//
//#Preview {
//    SearchSheet()
//        .modelContainer(SampleData.shared.modelContainer)
//}

#Preview {
    NavigationStack {
        AdventureDetail(adventure: Adventure.createSampleAdventure())
    }
}
