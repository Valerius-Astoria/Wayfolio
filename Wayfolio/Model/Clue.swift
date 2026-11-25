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
/// A clue with no conditions is unlocked as soon as the user opens it.
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
         icon: String = "folder",
         ismanualChecked: Bool = false, // no condition
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

    /// One label for each condition the clue has, in the order they're checked.
    var icons: [IconLabel] {
        [
            question.map { _ in QuestionCondition.label },
            location.map { _ in LocationCondition.label },
            photo.map { _ in PhotoCondition.label }
        ]
        .compactMap { $0 }
    }
    
    var isChecked: Bool {
        let conditions: [Checkable] = ([location, photo, question] as [Checkable?]).compactMap { $0 }
        // With no conditions, `allSatisfy` would always be true, so only the user's own check counts.
        guard !conditions.isEmpty else { return ismanualChecked }
        return conditions.allSatisfy { $0.isChecked } || ismanualChecked
    }
}


