//
//  FilterSheet.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import MapKit
import SwiftUI

/// Narrows the search results: what kinds to show, place categories, and adventure types and lengths.
struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: SearchFilter

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Show", selection: $filter.scope) {
                        ForEach(SearchFilter.Scope.allCases, id: \.self) { scope in
                            Text(scope.name)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if filter.showsPlaces {
                    Section("Place Categories") {
                        FlowLayout {
                            ForEach(MKPointOfInterestCategory.common, id: \.self) { category in
                                ChipToggle(title: LocalizedStringKey(category.label.name),
                                           icon: category.label.icon,
                                           color: category.label.color,
                                           isOn: $filter.categories.contains(category))
                            }
                        }
                    }
                }

                if filter.showsAdventures {
                    Section("Adventure Types") {
                        FlowLayout {
                            ForEach(AdventureType.allCases, id: \.self) { type in
                                ChipToggle(title: LocalizedStringKey(type.label.name),
                                           icon: type.label.icon,
                                           color: type.label.color,
                                           isOn: $filter.types.contains(type))
                            }
                        }
                    }
                    Section("Length") {
                        FlowLayout {
                            ForEach(TripLength.allCases, id: \.self) { length in
                                ChipToggle(title: length.name, isOn: $filter.lengths.contains(length))
                            }
                        }
                    }
                }
            }
            .animation(.default, value: filter.scope)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        withAnimation { filter = SearchFilter() }
                    }
                    .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    @Previewable @State var filter = SearchFilter()
    FilterSheet(filter: $filter)
}
