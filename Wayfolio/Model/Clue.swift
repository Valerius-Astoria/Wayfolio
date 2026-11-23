//
//  Clue.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import SwiftData

/// A clue hidden at a waypoint, which the user unlocks by meeting its `condition`.
@Model class Clue {
    var name: String
    /// A one-line summary shown before the clue is opened.
    var brief: String
    var detail: String?
    /// An SF Symbol name.
    var icon: String
    var isChecked: Bool
    /// What the user must do to check this clue. See `check(attempt:image:)`.
    var condition: Condition
    /// The position of this clue within its waypoint.
    var order: Int

    var waypoint: Waypoint

    init(name: String,
         brief: String,
         detail: String? = nil,
         icon: String = "folder",
         isChecked: Bool = false,
         waypoint: Waypoint,
         condition: Condition = .noCondition,
         order: Int) {
        self.name = name
        self.brief = brief
        self.detail = detail
        self.icon = icon
        self.isChecked = isChecked
        self.waypoint = waypoint
        self.condition = condition
        self.order = order
    }

    // MARK: - Setting conditions

    /// Requires the user to be within `radius` meters of the given coordinate.
    func addCoordinateCondition(latitude: Double, longitude: Double, radius: Double) {
        self.condition = .coordinate(latitude: latitude, longitude: longitude, radius: radius)
    }

    /// Requires the user to type `answer`. Case and surrounding whitespace are ignored.
    func addAnswerCondition(answer: String) {
        self.condition = .answer(answer)
    }

    /// Requires the user to take a photo similar to `uiImage`.
    ///
    /// The image is stored as JPEG.
    /// - Returns: `false` if the image can't be compressed, in which case the condition is unchanged.
    func addSimilarityCondition(uiImage: UIImage) -> Bool {
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else { return false }
        self.condition = .image(data)
        return true
    }

    // MARK: - Checking

    /// Checks `condition` and marks the clue as checked if it's met.
    ///
    /// - Parameters:
    ///   - attempt: The typed answer, for `.answer` conditions.
    ///   - image: The user's photo, for `.image` conditions.
    /// - Returns: `nil` if the condition is met, otherwise a message explaining why it isn't.
    func check(attempt: String? = nil, image: UIImage? = nil) async -> String? {
        if let errorMessage = await condition.check(attempt: attempt, image: image) {
            return errorMessage
        } else {
            isChecked = true
            return nil
        }
    }

    func uncheck() { self.isChecked = false }
}

