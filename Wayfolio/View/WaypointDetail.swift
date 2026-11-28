//
//  WaypointDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI

struct WaypointDetail: View {
    @State private var editMode: EditMode = .inactive
    @State private var isEditingHours = false
    @State private var draftHours = Hours()
    @FocusState private var isTextFieldFocused: Bool
    
    @Bindable var waypoint: Waypoint
    private var isEditing: Bool { editMode.isEditing }
    
    var body: some View {
        if !isEditing {
            HStack {
                VStack {
                    Text("Schedule").font(.title3)
                    Text(waypoint.schedule.display()).font(.subheadline)
                }
                .padding(.horizontal)
                
                Divider().frame(height: 36)
                
                VStack {
                    Text("IsOpen").font(.title3)
                    if let isOpening = waypoint.isOpening {
                        Text(isOpening ? "Open" : "Closed")
                            .foregroundStyle(isOpening ? Color.green : .red)
                            .font(.subheadline)
                    } else {
                        Text("Unknown")
                            .foregroundStyle(Color.gray)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                
                Divider().frame(height: 36)
                
                VStack {
                    Text("Status").font(.title3)
                    Text(waypoint.isChecked ? "Checked" : "Unchecked")
                        .foregroundStyle(waypoint.isChecked ? Color.green : .gray)
                        .font(.subheadline)
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)
        }
        
        List {
            if isEditing {
                HStack {
                    Text("Title").padding(.trailing, 5)
                    TextField(waypoint.name, text: $waypoint.name)
                        .foregroundStyle(.secondary)
                        .focused($isTextFieldFocused)
                }
            }
            
            if isEditing {
                Section("Schedule") {
                    ScheduleEditor(schedule: $waypoint.schedule)
                }
            }
            if let intro  = waypoint.intro {
                Section("Introduction") {
                    if isEditing {
                        TextField("Intro", text: $waypoint.intro.orEmpty, axis: .vertical)
                    } else {
                        Text(intro)
                    }
                }
            }
            if isEditing || !waypoint.clues.isEmpty {
                Section("Clues") {
                    ForEach(waypoint.orderedClues, id: \.persistentModelID) { clue in
                        if isEditing {
                            clueEditor(clue)
                        } else {
                            NavigationLink {
                                ClueDetail(clue: clue)
                            } label: {
                                clueRow(clue)
                            }
                        }
                    }
                    .onDelete(perform: waypoint.deleteClues(at:))
                    if isEditing {
                        Button {
                            withAnimation {
                                waypoint.addClue()
                            }
                        } label: {
                            AddRow("Add a clue")
                        }
                        .deleteDisabled(true)
                        .moveDisabled(true)
                    }
                }
            }
            Section("Hours") {
                if isEditing, waypoint.hours != nil {
                    // A button, not a `NavigationLink`: a list in edit mode ignores taps on links.
                    Button("Edit Hours", action: openHoursEditor)
                    Button("Remove Hours", role: .destructive) {
                        waypoint.hours = nil
                    }
                } else if let hours = waypoint.hours {
                    VStack {
                        ForEach(hours.grouped()) { group in
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(group.daysDisplay()): ")
                                Text(group.hoursDisplay())
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(group.isClosed ? .red : .secondary)
                            }
                        }
                    }
                } else {
                    Button("Add Hours", action: openHoursEditor)
                }
            }
            Section("Details") {
                HStack {
                    Text("Phone").padding(.trailing)
                    if isEditing {
                        TextField("Intro", text: $waypoint.phoneNumber.orEmpty, axis: .vertical)
                    } else {
                        Text(waypoint.phoneNumber ?? "Unknown")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Website").padding(.trailing)
                    if isEditing {
                        TextField("Website", text: Binding(
                            get: { waypoint.url?.absoluteString ?? "" },
                            set: { waypoint.url = $0.isEmpty ? nil : URL(string: $0) }
                        ))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    } else {
                        Text(waypoint.url?.absoluteString ?? "Unknown")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Address").padding(.trailing)
                    if isEditing {
                        TextField("Intro", text: $waypoint.fullAddress.orEmpty, axis: .vertical)
                    } else {
                        if waypoint.fullAddress != nil {
                            Text(waypoint.fullAddress ?? "")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Unknown")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        // Outside the list, because SwiftUI ignores a destination placed in a lazy container's row.
        .navigationDestination(isPresented: $isEditingHours) {
            HoursEditor(hours: $draftHours)
                .environment(\.editMode, .constant(.inactive))
        }
        .onChange(of: isEditingHours) { wasEditing, isEditingNow in
            if wasEditing, !isEditingNow {
                commitHoursEditor()
            }
        }
        .navigationTitle(waypoint.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
    }

    /// Opens the hours editor on a copy so nothing is saved until the user leaves the page.
    private func openHoursEditor() {
        draftHours = waypoint.hours ?? Hours()
        isEditingHours = true
    }

    /// Writes the draft if the user picked any days; otherwise leaves hours unset.
    private func commitHoursEditor() {
        waypoint.hours = draftHours.periods.isEmpty ? nil : draftHours
    }

    private func clueEditor(_ clue: Clue) -> some View {
        @Bindable var clue = clue
        return HStack {
            IconMenu(selection: $clue.icon, choices: Clue.Symbol.allCases)
                .padding(.trailing, 5)
                .foregroundStyle(.blue)
            TextField("Name", text: $clue.name)
                .focused($isTextFieldFocused)
        }
        .listRowBackground(Color.clear)
    }

    private func clueRow(_ clue: Clue) -> some View {
        Label {
            VStack(alignment: .leading) {
                HStack {
                    if clue.isChecked {
                        Circle()
                            .fill(.green)
                            .frame(width: 9, height: 9)
                    }
                    Text(clue.name)
                    ForEach(clue.icons, id: \.self) { label in
                        Image(systemName: label.icon)
                            .foregroundStyle(label.color)
                            .font(.footnote)
                    }
                }

                if let brief = clue.brief {
                    Text(brief)
                        .font(.footnote)
                        .foregroundStyle(.gray)
                }
            }
        } icon: {
            Image(systemName: clue.icon)
        }
    }
}

#Preview {
    NavigationStack {
        WaypointDetail(waypoint: Adventure.sampleData.first!.routes.first!.waypoints.first!)
    }
}
