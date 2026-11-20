//
//  Clue.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import SwiftData

/// Stores a clue hidden in one place.
@Model class Clue {
    var name: String
    var brief: String
    var detail: String?
    var icon: String
    var isChecked: Bool
    var condition: Condition
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

    /// `radius` is in meters.
    func addCoordinateCondition(latitude: Double, longitude: Double, radius: Double) {
        self.condition = .coordinate(latitude: latitude, longitude: longitude, radius: radius)
    }

    func addAnswerCondition(answer: String) {
        self.condition = .answer(answer)
    }

    /// - Returns `false` if compression fails.
    func addSimilarityCondition(uiImage: UIImage) -> Bool {
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else { return false }
        self.condition = .image(data)
        return true
    }

    /// - Returns: `nil` if check is perfomed successfully (regardless of the checking result), returns the reason of error when it fails. 
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

