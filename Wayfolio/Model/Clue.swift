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
    var brief: String?
    var detail: String
    var icon: String
    var isChecked: Bool
    var conditions: [Condition] = []
    var order: Int

    var waypoint: Waypoint

    init(name: String,
         brief: String? = nil,
         detail: String,
         icon: String = "folder",
         isChecked: Bool = false,
         waypoint: Waypoint,
         order: Int) {
        self.name = name
        self.brief = brief
        self.detail = detail
        self.icon = icon
        self.isChecked = isChecked
        self.waypoint = waypoint
        self.order = order
    }
    
    /// One label for each kind of condition used by the clues, sorted by icon name.
    var icons: [IconLabel] {
        Set(conditions.compactMap(\.label))
            .sorted { $0.icon < $1.icon }
    }

    // MARK: - Setting conditions

    /// Requires the user to be within `radius` meters of the given coordinate.
    func addCoordinateCondition(latitude: Double, longitude: Double, radius: Double) {
        self.conditions.append(.coordinate(latitude: latitude, longitude: longitude, radius: radius))
    }

    /// Requires the user to type `answer`. Case and surrounding whitespace are ignored.
    func addAnswerCondition(answer: String) {
        self.conditions.append(.answer(answer))
    }

    /// Requires the user to take a photo similar to `uiImage`.
    ///
    /// The image is stored as JPEG.
    /// - Returns: `false` if the image can't be compressed, in which case the condition is unchanged.
    func addSimilarityCondition(uiImage: UIImage) -> Bool {
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else { return false }
        self.conditions.append(.image(data))
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
        for condition in conditions {
            // Each condition should have diffierent types, therefore they can all be checked by `condition.check(attempt: attempt, image: image)`.
            if let errorMessage = await condition.check(attempt: attempt, image: image) {
                return errorMessage
            }
        }
        isChecked = true
        return nil
    }
}

