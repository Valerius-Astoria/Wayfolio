//
//  Clue.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import SwiftData

/// A clue hidden at a waypoint. Conditions can be solved independently; the clue is only
/// marked done when the user taps Check.
@Model class Clue {
    var name: String
    var brief: String?
    var detail: String
    var icon: String
    var ismanualChecked: Bool
    var order: Int

    var location: LocationCondition?
    var photo: PhotoCondition?
    var question: QuestionCondition?

    var waypoint: Waypoint

    init(clueName: String,
         brief: String? = nil,
         detail: String,
         icon: String = Symbol.others.rawValue,
         ismanualChecked: Bool = false,
         location: LocationCondition? = nil,
         photo: PhotoCondition? = nil,
         question: QuestionCondition? = nil,
         waypoint: Waypoint,
         order: Int) {
        self.name = clueName
        self.brief = brief
        self.detail = detail
        self.icon = icon
        self.ismanualChecked = ismanualChecked
        self.location = location
        self.photo = photo
        self.question = question
        self.waypoint = waypoint
        self.order = order
    }

    /// The symbols offered when picking a clue's icon, with the name shown in the menu.
    enum Symbol: String, CaseIterable, Identifiable, IconPickable {
        case letter = "envelope"
        case scroll = "scroll"
        case idea = "lightbulb"
        case key = "key.fill"
        case look = "binoculars"
        case star = "star"
        case riddle = "questionmark.circle"
        case photo = "camera"
        case others = "folder"

        var id: String { rawValue }
        var iconName: String { rawValue }

        var title: String {
            switch self {
            case .letter: "Letter"
            case .scroll: "Scroll"
            case .idea: "Idea"
            case .key: "Key"
            case .look: "Look"
            case .star: "Star"
            case .riddle: "Riddle"
            case .photo: "Photo"
            case .others: "Others"
            }
        }
    }

    /// One label for each condition the clue has, in the order they're checked.
    var icons: [IconLabel] {
        [
            question.map { _ in QuestionCondition.label },
            location.map { _ in LocationCondition.label },
            photo.map { _ in PhotoCondition.label }
        ]
        .compactMap { $0 }
    }
    
    /// Whether the user has marked this clue as done. Meeting its conditions is not enough.
    var isChecked: Bool { ismanualChecked }

    /// Whether every attached condition is currently satisfied. True when there are no conditions.
    var areConditionsMet: Bool {
        let conditions: [Checkable] = ([location, photo, question] as [Checkable?]).compactMap { $0 }
        return conditions.allSatisfy(\.isChecked)
    }

    // MARK: - Editing

    func addQuestion() {
        guard question == nil else { return }
        question = QuestionCondition(question: "", answer: "", hint: "")
    }

    func addLocation() {
        guard location == nil else { return }
        location = LocationCondition(
            latitude: waypoint.latitude,
            longitude: waypoint.longitude,
            radius: 50
        )
    }

    func addPhoto(from image: UIImage, name: String = "Photo") {
        guard photo == nil, let condition = PhotoCondition(name: name, reference: image) else { return }
        photo = condition
    }

    func replacePhoto(from image: UIImage, name: String? = nil) {
        guard let condition = PhotoCondition(name: name ?? photo?.name ?? "Photo", reference: image) else { return }
        photo = condition
    }
}


