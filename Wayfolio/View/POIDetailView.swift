//
//  POIDetailView.swift
//  Wayfolio
//
//  Created by ZAKA on 11/28/26.
//

import SwiftUI
import MapKit

struct POIDetailView: View {
    let item: MKMapItem
    
    @Environment(MapModel.self) var mapModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section("Details") {
                HStack {
                    Text("Phone").padding(.trailing, 5)
                    Text(item.phoneNumber ?? "Unknown")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Website").padding(.trailing, 5)
                    Text(item.url?.absoluteString ?? "Unknown")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Address").padding(.trailing, 5)
                    Text(item.address?.fullAddress ?? "Unknown")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(item.name ?? "Unknown")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if mapModel.isEditingRoute {
                    Button {
                        guard let route = mapModel.selectedRoute else { return }
                        if route.contains(item) {
                            route.removeWaypoint(matching: item)
                        } else {
                            route.addWaypoint(from: item)
                        }
                        dismiss()
                    } label: {
                        Image(systemName: mapModel.selectedRoute?.contains(item) == true ? "minus" : "plus")
                    }
                }
            }
        }
    }
}

