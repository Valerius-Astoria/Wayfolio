//
//  ClueDetail.swift
//  Wayfolio
//
//  Created by ZAKA on 11/24/26.
//

import SwiftUI
import PhotosUI

struct ClueDetail: View {
    let clue: Clue
    
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

    var body: some View {
        List {
            Section("Description") {
                Text(clue.detail)
            }
            
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
                        if questionAttemptCount >= question.threshhold, !question.isChecked {
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
        .listStyle(.plain)
        .navigationTitle(clue.name)
        .navigationBarTitleDisplayMode(.inline)
        
        if clue.photo == nil, clue.location == nil, clue.question == nil,
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

    /// Marks a clue with no conditions as checked, turning the Check button into a checkmark that then fades away.
    private func checkManually() {
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
}


//#Preview("Question") {
//    NavigationStack {
//        ClueDetail(clue: Adventure.sampleData.first!.routes.first!.orderedWaypoints[1].clues.first { $0.order == 0 }!)
//    }
//}

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
