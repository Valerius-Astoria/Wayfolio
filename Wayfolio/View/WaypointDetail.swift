//
//  WaypointDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import SwiftUI

/// A waypoint's page: when to visit, whether it's open, its clues, hours, and contact details.
///
/// While the adventure is running, a bar at the bottom checks the user in and moves on to the next stop,
/// and opening the page makes it the stop that Resume returns to.
struct WaypointDetail: View {
    @Environment(MapModel.self) private var map
    /// Owned here rather than read from the environment, because this view is the one that sets it.
    @State private var editMode: EditMode = .inactive
    @State private var isEditingHours = false
    @State private var isAddingClue = false
    @State private var isCheckingIn = false
    @State private var checkInError: String?

    @Bindable var waypoint: Waypoint
    private var isEditing: Bool { editMode.isEditing }
    private var adventure: Adventure { waypoint.route.adventure }
    private var isRunning: Bool { adventure.status == .started }

    var body: some View {
        VStack(spacing: 0) {
            summary
            List {
                if isEditing {
                    Section("Details") {
                        TextField("Name", text: $waypoint.name)
                        HStack {
                            Text("Icon")
                            Spacer()
                            IconMenu(selection: $waypoint.icon, choices: Waypoint.iconChoices)
                        }
                        Toggle("Require Arrival", isOn: requiresArrival)
                        if let location = waypoint.location {
                            Stepper("Within \(Int(location.radius)) m",
                                    value: $waypoint.location.unwrapped(or: location).radius, in: 10...500, step: 10)
                        }
                    }
                    Section("Schedule") {
                        ScheduleEditor(schedule: $waypoint.schedule)
                    }
                }
                if isEditing || waypoint.intro != nil {
                    Section("Introduction") {
                        if isEditing {
                            TextField("Intro", text: $waypoint.intro.orEmpty, axis: .vertical)
                        } else {
                            Text(waypoint.intro ?? "")
                        }
                    }
                }
                if isEditing || !waypoint.clues.isEmpty {
                    clueSection
                }
                hoursSection
                contactSection
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                if !isEditing {
                    runBar
                }
            }
        }
        // Outside the list, because SwiftUI ignores a destination placed in a lazy container's row.
        .navigationDestination(isPresented: $isEditingHours) {
            if let hours = waypoint.hours {
                HoursEditor(hours: $waypoint.hours.unwrapped(or: hours))
                    .environment(\.editMode, .constant(.inactive))
            }
        }
        .sheet(isPresented: $isAddingClue) {
            AddClueSheet(waypoint: waypoint)
        }
        .navigationTitle(waypoint.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .sensoryFeedback(.success, trigger: waypoint.isChecked) { _, isChecked in isChecked }
        .onAppear {
            if isRunning {
                adventure.currentWaypoint = waypoint
            }
        }
    }

    // MARK: - Summary

    /// When to visit, whether the place is open now, and whether the user has checked in.
    private var summary: some View {
        HStack {
            summaryItem("Visit", value: Text(verbatim: waypoint.schedule.display()), color: .primary)
            Divider().frame(height: 36)
            switch waypoint.isOpenNow {
            case true?: summaryItem("Hours", value: Text("Open now"), color: .green)
            case false?: summaryItem("Hours", value: Text("Closed now"), color: .red)
            case nil: summaryItem("Hours", value: Text("No hours"), color: .secondary)
            }
            Divider().frame(height: 36)
            summaryItem("Progress",
                        value: Text(waypoint.isChecked ? "Checked in" : "Not yet"),
                        color: waypoint.isChecked ? .green : .secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func summaryItem(_ title: LocalizedStringKey, value: Text, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            value
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    private var clueSection: some View {
        Section("Clues") {
            ForEach(waypoint.orderedClues, id: \.self) { clue in
                NavigationLink(value: MapDestination.clue(clue)) {
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
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: clue.icon)
                    }
                }
            }
            .onDelete(perform: waypoint.deleteClues(at:))
            .onMove(perform: waypoint.moveClues)

            if isEditing {
                AddItemButton("Add Clue") { isAddingClue = true }
            }
        }
    }

    private var hoursSection: some View {
        Section("Hours") {
            if isEditing, waypoint.hours != nil {
                // A button, not a `NavigationLink`: a list in edit mode ignores taps on links.
                Button("Edit Hours") {
                    isEditingHours = true
                }
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
                Button("Add Hours") {
                    waypoint.hours = Hours(open: .init(9), close: .init(17))
                }
            }
        }
    }

    private var contactSection: some View {
        Section("Contact") {
            contactRow("Phone") {
                TextField("Phone", text: $waypoint.phoneNumber.orEmpty)
                    .keyboardType(.phonePad)
            } value: {
                waypoint.phoneNumber
            }
            contactRow("Website") {
                TextField("Website", text: Binding(
                    get: { waypoint.url?.absoluteString ?? "" },
                    set: { waypoint.url = $0.isEmpty ? nil : URL(string: $0) }
                ))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            } value: {
                waypoint.url?.absoluteString
            }
            contactRow("Address") {
                TextField("Address", text: $waypoint.fullAddress.orEmpty, axis: .vertical)
            } value: {
                waypoint.fullAddress
            }
        }
    }

    /// A contact detail: a field while editing, otherwise the value or "Unknown".
    private func contactRow(_ title: LocalizedStringKey,
                            @ViewBuilder editor: () -> some View,
                            value: () -> String?) -> some View {
        HStack {
            Text(title).padding(.trailing)
            if isEditing {
                editor()
            } else {
                Text(value() ?? String(localized: "Unknown"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Running

    /// Check In on the leading side while the adventure is running, and Next on the trailing side.
    @ViewBuilder
    private var runBar: some View {
        let next = adventure.waypoint(after: waypoint)
        let showsCheckIn = isRunning && !waypoint.isChecked
        if showsCheckIn || next != nil {
            VStack(alignment: .leading, spacing: 6) {
                if showsCheckIn, let caption = checkInCaption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(checkInError == nil ? Color.secondary : .red)
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                }
                HStack {
                    if showsCheckIn {
                        checkInButton
                    }
                    Spacer()
                    if let next {
                        nextButton(to: next)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .animation(.default, value: checkInError)
        }
    }

    /// Why Check In is unavailable, or why it just failed.
    private var checkInCaption: String? {
        if let checkInError { return checkInError }
        if !waypoint.areCluesChecked { return String(localized: "Finish the clues first") }
        return nil
    }

    private var checkInButton: some View {
        Button {
            Task { await checkIn() }
        } label: {
            HStack(spacing: 6) {
                if isCheckingIn {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text("Check In")
            }
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(waypoint.areCluesChecked ? Color.green : .secondary)
        .glassEffect(.regular.tint(.green.opacity(waypoint.areCluesChecked ? 0.2 : 0)).interactive(), in: .capsule)
        .disabled(!waypoint.areCluesChecked || isCheckingIn)
    }

    private func nextButton(to next: Waypoint) -> some View {
        Button {
            if isRunning {
                adventure.currentWaypoint = next
            }
            map.showWaypoint(next)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Next")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(next.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                Image(systemName: "arrow.right")
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Next: \(next.name)")
    }

    /// Checks the waypoint, verifying the user's location first if it requires arrival.
    private func checkIn() async {
        isCheckingIn = true
        defer { isCheckingIn = false }
        do {
            try await waypoint.check()
            checkInError = nil
        } catch {
            checkInError = error.localizedDescription
        }
    }

    // MARK: - Editing

    /// Whether the user has to be at the waypoint to check it. Turning it on uses the default radius.
    private var requiresArrival: Binding<Bool> {
        Binding(
            get: { waypoint.location != nil },
            set: { isOn in
                if isOn {
                    waypoint.requireArrival()
                } else {
                    waypoint.location = nil
                }
            }
        )
    }
}
//
//#Preview {
//    WaypointDetail(waypoint: Adventure.sampleData.first!.routes.first!.orderedWaypoints.first!)
//        .previewInMapStack()
//}
