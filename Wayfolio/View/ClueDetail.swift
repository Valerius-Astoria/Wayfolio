//
//  ClueDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/24/26.
//

import SwiftUI
import PhotosUI

struct ClueDetail: View {
    @Bindable var clue: Clue
    
    /// Owned here rather than read from the environment, because this view is the one that sets it.
    @State private var editMode: EditMode = .inactive
    @State private var isAddingQuestion = false
    @State private var isAddingPhoto = false
    /// A new reference photo picked while editing the photo condition.
    @State private var replacementPhoto: PhotosPickerItem?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var answer: String = ""
    @State private var photoError: String?
    @State private var questionError: String?
    @State private var questionAttemptCount: Int = 0
    @State private var locationError: String?
    @State private var isComparingImage = false
    @State private var isCheckingLocation = false
    /// Whether the checkmark that replaces the Check button is showing. It hides itself shortly after appearing.
    @State private var isShowingCheckmark = false

    init(clue: Clue) {
        self.clue = clue
        _answer = State(initialValue: clue.question?.response ?? "")
    }

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        List {
            if isEditing {
                Section("Details") {
                    TextField("Name", text: $clue.name)
                    TextField("Brief", text: $clue.brief.orEmpty, axis: .vertical)
                    HStack {
                        Text("Icon")
                        Spacer()
                        IconMenu(selection: $clue.icon, choices: Clue.iconChoices)
                    }
                    TextField("Detail", text: $clue.detail, axis: .vertical)
                        .lineLimit(3...)
                }
                conditionEditors
            } else {
                Section("Description") {
                    Text(clue.detail)
                }
                conditionChecks
            }
        }
        .listStyle(.plain)
        .navigationTitle(clue.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $isAddingQuestion) {
            AddQuestionSheet(clue: clue)
        }
        .sheet(isPresented: $isAddingPhoto) {
            AddPhotoSheet(clue: clue)
        }
        
        if !isEditing, clue.photo == nil, clue.location == nil, clue.question == nil,
           !clue.isChecked || isShowingCheckmark {
            HStack {
                Spacer()
                if !clue.isChecked {
                    Button(action: checkManually) {
                        Text("Check")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                            .font(.title3)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else if isShowingCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .padding(.horizontal, 20)
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
        }
    }

    // MARK: - Checking

    /// A section for each condition, where the user meets it.
    @ViewBuilder
    private var conditionChecks: some View {
            if var photo = clue.photo {
                Section("Image") {
                    HStack {
                        if let uiImage = photo.referenceImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 40, maxHeight: 40)
                        }
                        VStack(alignment: .leading) {
                            Text(photo.name)
                            if let photoError {
                                Text(photoError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        if !photo.isChecked {
                            if isComparingImage {
                                ProgressView()
                            } else {
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Image(systemName: "plus.app").font(.title3).foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                        }
                    }
                    .task(id: selectedPhoto) {
                        guard let selectedPhoto else { return }
                        isComparingImage = true
                        defer { isComparingImage = false }
                        do {
                            guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                                  let image = UIImage(data: data) else {
                                throw ConditionFailure("Couldn't load the selected photo.")
                            }
                            try photo.check(photo: image)
                            clue.photo = photo
                            photoError = nil
                        } catch {
                            photoError = error.localizedDescription
                        }
                    }
                }
            }
            
            if var question = clue.question {
                Section("Question") {
                    VStack(alignment: .leading) {
                        Text(question.question)
                        HStack {
                            TextField("Your answer", text: $answer)
                                .disabled(question.isChecked)
                                .onSubmit { questionAttemptCount += 1 }
                            Spacer()
                            if !answer.isEmpty {
                                if question.isChecked {
                                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                                } else {
                                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.red)
                                }
                            }
                        }
                        if questionAttemptCount >= question.threshold, !question.isChecked {
                            Text(question.hint)
                                .font(.footnote)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .task(id: answer) {
                    // Skip the initial run, when `answer` was just loaded from the stored response.
                    guard answer != question.response ?? "" else { return }
                    do {
                        try question.check(answer: answer)
                        questionError = nil
                    } catch {
                        questionError = error.localizedDescription
                    }
                    clue.question = question
                }
            }
            
            if let location = clue.location {
                Section("Location") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(location.guide)
                            if let locationError {
                                Text(locationError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        if !location.isChecked {
                            if isCheckingLocation {
                                ProgressView()
                            } else {
                                Button {
                                    Task {
                                        isCheckingLocation = true
                                        defer { isCheckingLocation = false }
                                        var location = location
                                        do {
                                            try await location.check()
                                            clue.location = location
                                            locationError = nil
                                        } catch {
                                            locationError = error.localizedDescription
                                        }
                                    }
                                } label: {
                                    Text("Check")
                                        .foregroundStyle(.blue)
                                }
                            }
                        } else {
                            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                        }
                    }
                }
            }
    }

    // MARK: - Editing

    /// An editor for each condition, and a menu for adding the kinds the clue doesn't have yet.
    @ViewBuilder
    private var conditionEditors: some View {
        if let question = clue.question {
            let question = $clue.question.unwrapped(or: question)
            Section {
                TextField("Question", text: question.question, axis: .vertical)
                TextField("Answer", text: question.answer)
                    .autocorrectionDisabled()
                TextField("Hint", text: question.hint, axis: .vertical)
                Stepper("Show hint after \(question.wrappedValue.threshold) tries",
                        value: question.threshold, in: 1...20)
            } header: {
                conditionHeader("Question") { clue.question = nil }
            }
        }

        if let location = clue.location {
            let location = $clue.location.unwrapped(or: location)
            Section {
                TextField("Guide", text: location.guide, axis: .vertical)
                Stepper("Within \(Int(location.wrappedValue.radius)) m",
                        value: location.radius, in: 10...500, step: 10)
            } header: {
                conditionHeader("Location") { clue.location = nil }
            }
        }

        if let photo = clue.photo {
            let binding = $clue.photo.unwrapped(or: photo)
            Section {
                TextField("Name", text: binding.name)
                HStack {
                    if let uiImage = photo.referenceImage {
                        Image(uiImage: uiImage)
                            .thumbnailStyle(width: 54, height: 54)
                    }
                    Spacer()
                    PhotosPicker("Replace Photo", selection: $replacementPhoto, matching: .images)
                }
                VStack(alignment: .leading) {
                    Text("Match")
                    // A lower threshold means the photo has to be more similar.
                    Slider(value: binding.threshold, in: 0.1...1) {
                        Text("Match")
                    } minimumValueLabel: {
                        Text("Strict").font(.caption)
                    } maximumValueLabel: {
                        Text("Loose").font(.caption)
                    }
                }
            } header: {
                conditionHeader("Photo") { clue.photo = nil }
            }
            .task(id: replacementPhoto) {
                guard let data = try? await replacementPhoto?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let current = clue.photo else { return }
                clue.photo = PhotoCondition(name: current.name, reference: image, threshold: current.threshold)
                replacementPhoto = nil
            }
        }

        if clue.question == nil || clue.location == nil || clue.photo == nil {
            Section {
                Menu {
                    if clue.question == nil {
                        Button("Question", systemImage: QuestionCondition.label.icon) { isAddingQuestion = true }
                    }
                    if clue.location == nil {
                        // Nothing to ask for: it starts at the waypoint with the default radius.
                        Button("Location", systemImage: LocationCondition.label.icon) {
                            clue.location = LocationCondition(latitude: clue.waypoint.latitude,
                                                              longitude: clue.waypoint.longitude,
                                                              radius: 50)
                        }
                    }
                    if clue.photo == nil {
                        Button("Photo", systemImage: PhotoCondition.label.icon) { isAddingPhoto = true }
                    }
                } label: {
                    Label("Add Condition", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
                .listRowSeparator(.hidden)
            }
        }
    }

    /// A section title with a button that removes the condition.
    private func conditionHeader(_ title: LocalizedStringKey, remove: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("Remove", role: .destructive) {
                withAnimation { remove() }
            }
            .font(.footnote)
            .textCase(nil)
        }
    }

    /// Marks a clue with no conditions as checked, turning the Check button into a checkmark that then fades away.
    private func checkManually() {
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) {
            clue.isManuallyChecked = true
            isShowingCheckmark = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.easeOut(duration: 0.3)) {
                isShowingCheckmark = false
            }
        }
    }
}


//#Preview("Question") {
//    NavigationStack {
//        ClueDetail(clue: Adventure.sampleData.first!.routes.first!.orderedWaypoints[1].clues.first { $0.order == 0 }!)
//    }
//}

#Preview("Photo") {
    ClueDetail(clue: Adventure.sampleData.first!.routes.first!.orderedWaypoints[1].clues.first { $0.order == 0 }!)
        .previewInMapStack()
}

#Preview("All Conditions") {
    ClueDetail(clue: Adventure.sampleData.first!.routes.first!.orderedWaypoints[1].clues.first { $0.order == 2 }!)
        .previewInMapStack()
}

#Preview("No Conditions") {
    ClueDetail(clue: Adventure.sampleData.first!.routes.first { $0.day == 1 }!.orderedWaypoints[0].clues.first { $0.order == 0 }!)
        .previewInMapStack()
}
