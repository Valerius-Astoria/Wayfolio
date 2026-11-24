//
//  Condition.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import Foundation
import SwiftUI
import Vision
import MapKit

// Each kind of condition is its own type, so a clue or waypoint can hold at most one of each,
// and each check only takes the input it needs.

/// Met when the user is within `radius` meters of a coordinate.
struct LocationCondition: Checkable, Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var radius: Double
    var isChecked = false
    var guide = "Move to the right position"

    static let label = IconLabel(icon: "mappin.circle", color: .orange)

    /// Gets the user's current location and compares its distance to the target with `radius`.
    ///
    /// - Throws: `ConditionFailure` if the user's location isn't available or the user is too far away.
    mutating func check() async throws {
        let userLocation: CLLocation
        do {
            userLocation = try await LocationTracker.currentLocation()
        } catch let error as LocationError {
            throw ConditionFailure(error.message)
        } catch {
            throw ConditionFailure("Your location isn't available: \(error.localizedDescription)")
        }

        let distance = userLocation.distance(from: CLLocation(latitude: latitude, longitude: longitude))

        guard distance <= radius else {
            throw ConditionFailure("You're about \(Int(distance.rounded())) m away. Get within \(Int(radius.rounded())) m of the spot.")
        }
        isChecked = true
    }
}

/// Met when the user's photo looks similar to a reference photo.
struct PhotoCondition: Checkable, Codable, Hashable {
    var name: String
    /// JPEG data.
    var reference: Data
    /// The maximum Vision feature-print distance that counts as similar. Lower means stricter.
    var threshold: Float = 0.5
    var isChecked = false

    static let label = IconLabel(icon: "photo", color: .orange)

    /// - Returns: `nil` if `image` can't be compressed.
    init?(name: String, reference image: UIImage, threshold: Float = 0.5) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        self.name = name
        self.reference = data
        self.threshold = threshold
    }

    var referenceImage: UIImage? { UIImage(data: reference) }

    /// Compares `photo` with `reference` using Vision feature prints.
    ///
    /// - Throws: `ConditionFailure` if the photo isn't similar enough or can't be analyzed.
    mutating func check(photo: UIImage?) throws {
        guard let photo else { throw ConditionFailure("Take a photo first.") }
        guard let referenceCG = referenceImage?.cgImage else {
            throw ConditionFailure("The reference photo is missing or corrupted.")
        }
        guard let photoCG = photo.cgImage else {
            throw ConditionFailure("Couldn't read the photo you provided.")
        }
        
        func featurePrint(for cgImage: CGImage) throws -> VNFeaturePrintObservation {
            let request = VNGenerateImageFeaturePrintRequest()
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
            guard let result = request.results?.first else { throw ConditionFailure("Couldn't analyze the photos.") }
            return result
        }
        
        var distance: Float = 0
        do {
            try featurePrint(for: referenceCG).computeDistance(&distance, to: featurePrint(for: photoCG))
        } catch let failure as ConditionFailure {
            throw failure
        } catch {
            throw ConditionFailure("Photo comparison failed: \(error.localizedDescription)")
        }
        
        guard distance < threshold else {
            throw ConditionFailure("Your photo doesn't look similar enough to the target, only \(1-distance) similarity.")
        }
        isChecked = true
    }
}

/// Met when the user types the answer to a question.
struct QuestionCondition: Checkable, Codable, Hashable {
    var question: String
    /// Case and surrounding whitespace are ignored when checking.
    var answer: String
    var isChecked = false
    var hint: String
    var threshhold = 8

    static let label = IconLabel(icon: "pencil.circle", color: .orange)

    /// - Throws: `ConditionFailure` if `attempt` is empty or wrong.
    mutating func check(answer attempt: String?) throws {
        let attempt = attempt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !attempt.isEmpty else { return }

        let answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard attempt.caseInsensitiveCompare(answer) == .orderedSame else {
            throw ConditionFailure("That answer isn't correct.")
        }
        isChecked = true
    }
}

/// Why a condition isn't met, in a form that can be shown to the user.
struct ConditionFailure: LocalizedError {
    let message: String

    init(_ message: String) { self.message = message }

    var errorDescription: String? { message }
}

protocol Checkable {
    var isChecked: Bool { get }
}
