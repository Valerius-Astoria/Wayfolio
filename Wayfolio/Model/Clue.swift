//
//  Clue.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import SwiftData

/// A clue hidden at a waypoint, which the user unlocks by meeting all of its conditions.
///
/// A clue with no conditions is checked by hand with its Check button.
@Model class Clue {
    var name: String
    var brief: String?
    var detail: String
    var icon: String
    /// Whether the user checked a clue that has no conditions. Ignored once the clue has conditions.
    var isManuallyChecked: Bool
    var order: Int

    var location: LocationCondition?
    var photo: PhotoCondition?
    var question: QuestionCondition?

    var waypoint: Waypoint

    init(name: String,
         brief: String? = nil,
         detail: String,
         icon: String = "folder",
         isManuallyChecked: Bool = false,
         location: LocationCondition? = nil,
         photo: PhotoCondition? = nil,
         question: QuestionCondition? = nil,
         waypoint: Waypoint,
         order: Int) {
        self.name = name
        self.brief = brief
        self.detail = detail
        self.icon = icon
        self.isManuallyChecked = isManuallyChecked
        self.location = location
        self.photo = photo
        self.question = question
        self.waypoint = waypoint
        self.order = order
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
    
    /// Whether every condition is met, or, for a clue with no conditions, whether the user checked it.
    var isChecked: Bool {
        let conditions: [Checkable] = ([location, photo, question] as [Checkable?]).compactMap { $0 }
        // With no conditions, `allSatisfy` would always be true, so only the user's own check counts.
        guard !conditions.isEmpty else { return isManuallyChecked }
        return conditions.allSatisfy(\.isChecked)
    }

    /// Unchecks the clue and each of its conditions, and forgets the last answer typed.
    func resetProgress() {
        isManuallyChecked = false
        location?.isChecked = false
        photo?.isChecked = false
        question?.isChecked = false
        question?.response = nil
    }
}


