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
    @State private var editMode: EditMode = .inactive

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var referencePhoto: PhotosPickerItem?
    @State private var answer: String = ""
    @State private var photoError: String?
    @State private var questionError: String?
    @State private var questionAttemptCount: Int = 0
    @State private var locationError: String?
    @State private var isComparingImage = false
    @State private var isCheckingLocation = false
    /// Whether the checkmark that replaces the Check button is showing. It hides itself shortly after appearing.
    @State private var isShowingCheckmark = false
    @State private var isRejected = false
    @State private var shiverCount = 0
    @State private var questionEditorError: String?
    @State private var answerEditorError: String?
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEditing: Bool { editMode.isEditing }

    init(clue: Clue) {
        self.clue = clue
        _answer = State(initialValue: clue.question?.response ?? "")
    }

    var body: some View {
        List {
            if isEditing {
                Section {
                    HStack {
                        Text("Title").padding(.trailing, 5)
                        TextField("Title", text: $clue.name)
                            .foregroundStyle(.secondary)
                            .focused($isTextFieldFocused)
                    }
                    HStack {
                        Text("Subtitle").padding(.trailing, 5)
                        TextField("Brief", text: $clue.brief.orEmpty, axis: .vertical)
                            .foregroundStyle(.secondary)
                            .focused($isTextFieldFocused)
                    }
                }
            }

            Section("Description") {
                if isEditing {
                    TextField("Detail", text: $clue.detail, axis: .vertical)
                        .focused($isTextFieldFocused)
                } else {
                    Text(clue.detail)
                }
            }

            if clue.photo != nil {
                photoSection
            }
            if clue.question != nil {
                questionSection
            }
            if clue.location != nil {
                locationSection
            }

            if isEditing, clue.question == nil || clue.photo == nil || clue.location == nil {
                Section("Conditions") {
                    if clue.question == nil {
                        Button {
                            withAnimation { clue.addQuestion() }
                        } label: {
                            AddRow("Add a question")
                        }
                    }
                    if clue.photo == nil {
                        PhotosPicker(selection: $referencePhoto, matching: .images) {
                            AddRow("Add a photo")
                        }
                    }
                    if clue.location == nil {
                        Button {
                            withAnimation {
                                clue.addLocation()
                                setLocationToWaypoint()
                            }
                        } label: {
                            AddRow("Add a location")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(clue.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { wasEditing, isEditing in
            guard wasEditing.isEditing, !isEditing.isEditing else { return }
            guard let question = clue.question, !question.isFilled else {
                questionEditorError = nil
                answerEditorError = nil
                return
            }
            editMode = .active
            showQuestionEditorErrors()
        }
        .onChange(of: referencePhoto) { _, item in
            Task { await applyReferencePhoto(item) }
        }

        if !isEditing, !clue.isChecked || isShowingCheckmark {
            HStack {
                Spacer()
                if !clue.isChecked {
                    Button(action: checkManually) {
                        Text("Check")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isRejected ? .red : .blue, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                            .font(.title3)
                    }
                    .animation(.easeInOut(duration: 0.1), value: isRejected)
                    .keyframeAnimator(initialValue: 0.0, trigger: shiverCount) { content, offset in
                        content.offset(x: reduceMotion ? 0 : offset)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(10, duration: 0.08)
                            LinearKeyframe(-10, duration: 0.08)
                            LinearKeyframe(8, duration: 0.08)
                            LinearKeyframe(-8, duration: 0.08)
                            LinearKeyframe(6, duration: 0.08)
                            LinearKeyframe(-6, duration: 0.08)
                            LinearKeyframe(4, duration: 0.08)
                            LinearKeyframe(-4, duration: 0.1)
                            LinearKeyframe(0, duration: 0.12)
                        }
                    }
                    .sensoryFeedback(.error, trigger: shiverCount)
                    .accessibilityHint(clue.areConditionsMet ? "Marks this clue as done." : "All conditions must be met first.")
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

    // MARK: - Conditions

    @ViewBuilder
    private var photoSection: some View {
        if var photo = clue.photo {
            Section("Image") {
                if isEditing {
                    if let uiImage = photo.referenceImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                    }
                    HStack {
                        Text("Hint").padding(.trailing, 5)
                        TextField("Name", text: photoName)
                            .focused($isTextFieldFocused)
                            .foregroundStyle(.secondary)
                    }
                    PhotosPicker(selection: $referencePhoto, matching: .images) {
                        Label("Change photo", systemImage: "photo")
                    }
                    Button("Remove Photo", role: .destructive) {
                        withAnimation { clue.photo = nil }
                    }
                } else {
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
                        if !clue.isChecked {
                            if isComparingImage {
                                ProgressView()
                            } else {
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Image(systemName: "plus.app").font(.title3).foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Choose a new photo")
                            }
                        }
                        if photo.isChecked {
                            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                        }
                    }
                    .task(id: selectedPhoto) {
                        guard !clue.isChecked, let selectedPhoto else { return }
                        isComparingImage = true
                        defer { isComparingImage = false }
                        do {
                            guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                                  let image = UIImage(data: data) else {
                                throw ConditionFailure("Couldn't load the selected photo.")
                            }
                            try photo.check(photo: image)
                            photoError = nil
                        } catch {
                            photoError = error.localizedDescription
                        }
                        clue.photo = photo
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var questionSection: some View {
        if var question = clue.question {
            Section("Question") {
                if isEditing {
                    HStack {
                        Text("Question").padding(.trailing, 5)
                        TextField("Question", text: questionText, axis: .vertical)
                            .focused($isTextFieldFocused)
                            .foregroundStyle(.secondary)
                    }
                    if let questionEditorError {
                        Text(questionEditorError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    HStack {
                        Text("Answer").padding(.trailing, 5)
                        TextField("Answer", text: questionAnswer)
                            .focused($isTextFieldFocused)
                            .foregroundStyle(.secondary)
                    }
                    if let answerEditorError {
                        Text(answerEditorError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    HStack {
                        Text("Hint").padding(.trailing, 5)
                        TextField("Hint", text: questionHint, axis: .vertical)
                            .focused($isTextFieldFocused)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Remove Question", role: .destructive) {
                        withAnimation {
                            clue.question = nil
                            questionEditorError = nil
                            answerEditorError = nil
                        }
                    }
                } else {
                    VStack(alignment: .leading) {
                        Text(question.question)
                        HStack {
                            TextField("Your answer", text: $answer)
                                .disabled(clue.isChecked)
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
                        if let questionError, !question.isChecked {
                            Text(questionError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        if questionAttemptCount >= question.threshhold, !question.isChecked {
                            Text(question.hint)
                                .font(.footnote)
                                .foregroundStyle(.gray)
                        }
                    }
                    .task(id: answer) {
                        guard !clue.isChecked, answer != question.response ?? "" else { return }
                        do {
                            try question.check(answer: answer)
                            questionError = nil
                        } catch {
                            questionError = error.localizedDescription
                        }
                        clue.question = question
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        if let location = clue.location {
            Section("Location") {
                if isEditing {
                    HStack {
                        Text("Hint").padding(.trailing, 5)
                        TextField("Guide", text: locationGuide, axis: .vertical)
                            .focused($isTextFieldFocused)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Radius").padding(.trailing, 5)
                        Stepper(value: locationRadius, in: 5...1_000, step: 5) {
                            Text("\(Int(location.radius)) m")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button("Remove Location", role: .destructive) {
                        withAnimation { clue.location = nil }
                    }
                } else {
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
                        if !clue.isChecked {
                            if isCheckingLocation {
                                ProgressView()
                            } else {
                                Button("Check", action: checkLocation)
                                    .foregroundStyle(.blue)
                            }
                        }
                        if location.isChecked {
                            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bindings

    private var photoName: Binding<String> {
        Binding(
            get: { clue.photo?.name ?? "" },
            set: { value in
                guard var photo = clue.photo else { return }
                photo.name = value
                clue.photo = photo
            }
        )
    }

    private var questionText: Binding<String> {
        Binding(
            get: { clue.question?.question ?? "" },
            set: { value in
                guard var question = clue.question else { return }
                question.question = value
                clue.question = question
                if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    questionEditorError = nil
                }
            }
        )
    }

    private var questionAnswer: Binding<String> {
        Binding(
            get: { clue.question?.answer ?? "" },
            set: { value in
                guard var question = clue.question else { return }
                question.answer = value
                clue.question = question
                if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    answerEditorError = nil
                }
            }
        )
    }

    private var questionHint: Binding<String> {
        Binding(
            get: { clue.question?.hint ?? "" },
            set: { value in
                guard var question = clue.question else { return }
                question.hint = value
                clue.question = question
            }
        )
    }

    private var locationGuide: Binding<String> {
        Binding(
            get: { clue.location?.guide ?? "" },
            set: { value in
                guard var location = clue.location else { return }
                location.guide = value
                clue.location = location
            }
        )
    }

    private var locationRadius: Binding<Double> {
        Binding(
            get: { clue.location?.radius ?? 50 },
            set: { value in
                guard var location = clue.location else { return }
                location.radius = value
                clue.location = location
            }
        )
    }

    // MARK: - Actions

    /// Marks the clue as done if every condition is met; otherwise the button shivers in red.
    private func checkManually() {
        guard clue.areConditionsMet else {
            rejectCheck()
            return
        }
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) {
            clue.ismanualChecked = true
            isShowingCheckmark = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.easeOut(duration: 0.3)) {
                isShowingCheckmark = false
            }
        }
    }

    private func rejectCheck() {
        showUnmetConditionErrors()
        shiverCount += 1
        withAnimation(.easeInOut(duration: 0.3)) {
            isRejected = true
        } completion: {
            withAnimation(.easeInOut(duration: 0.5)) {
                isRejected = false
            }
        }
    }

    private func showQuestionEditorErrors() {
        let question = clue.question?.question.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let answer = clue.question?.answer.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        questionEditorError = question.isEmpty ? "Enter a question." : nil
        answerEditorError = answer.isEmpty ? "Enter an answer." : nil
    }

    /// Fills each unsolved condition's error so it appears in that section.
    private func showUnmetConditionErrors() {
        if let photo = clue.photo, !photo.isChecked {
            photoError = photoError ?? photo.unmetMessage
        }
        if let question = clue.question, !question.isChecked {
            questionError = question.unmetMessage(for: answer)
            questionAttemptCount += 1
        }
        if let location = clue.location, !location.isChecked {
            locationError = locationError ?? location.unmetMessage
            checkLocation()
        }
    }

    private func checkLocation() {
        guard !clue.isChecked, let location = clue.location else { return }
        Task {
            isCheckingLocation = true
            defer { isCheckingLocation = false }
            var location = location
            do {
                try await location.check()
                locationError = nil
            } catch {
                locationError = error.localizedDescription
            }
            clue.location = location
        }
    }

    private func applyReferencePhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        if clue.photo == nil {
            clue.addPhoto(from: image)
        } else {
            clue.replacePhoto(from: image)
        }
        referencePhoto = nil
    }

    private func setLocationToWaypoint() {
        guard var location = clue.location else { return }
        location.latitude = clue.waypoint.latitude
        location.longitude = clue.waypoint.longitude
        clue.location = location
    }
}

#Preview("Photo") {
    NavigationStack {
        ClueDetail(clue: Adventure.sampleData.first!.routes.first!.orderedWaypoints[1].clues.first { $0.order == 0 }!)
    }
}

#Preview("All Conditions") {
    NavigationStack {
        ClueDetail(clue: Adventure.sampleData.first!.routes.first!.orderedWaypoints[1].clues.first { $0.order == 2 }!)
    }
}

#Preview("No Conditions") {
    NavigationStack {
        ClueDetail(clue: Adventure.sampleData.first!.routes.first { $0.day == 1 }!.orderedWaypoints[0].clues.first { $0.order == 0 }!)
    }
}
