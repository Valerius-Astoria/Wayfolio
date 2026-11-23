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

/// A requirement the user must meet to check a waypoint or clue.
enum Condition: Codable {
    /// Always met.
    case noCondition
    /// Met when the user is within `radius` meters of the coordinate.
    case coordinate(latitude: Double, longitude: Double, radius: Double)
    /// Met when the user's photo looks similar to this reference image (JPEG data).
    case image(Data)
    /// Met when the user types this answer. Case and surrounding whitespace are ignored.
    case answer(String)

    // MARK: - Checking

    /// Checks whether the condition is met.
    ///
    /// This doesn't change any state. The caller is responsible for marking its waypoint or clue as checked.
    /// - Parameters:
    ///   - attempt: The typed answer, for `.answer` conditions.
    ///   - image: The user's photo, for `.image` conditions.
    /// - Returns: `nil` if the condition is met, otherwise a message explaining why it isn't.
    func check(attempt: String? = nil, image: UIImage? = nil) async -> String? {
        let failure: String?

        switch self {
        case .noCondition:
            failure = nil
        case .coordinate(let latitude, let longitude, let radius):
            failure = await checkCoordinate(latitude: latitude, longitude: longitude, radius: radius)
        case .image(let data):
            guard let image else { return "No photo was provided." }
            failure = checkSimilarity(reference: data, attempt: image)
        case .answer(let answer):
            guard let attempt else { return "No answer was provided." }
            failure = checkAnswer(attempt: attempt, answer: answer)
        }

        return failure
    }

    // MARK: - Private checks (each returns `nil` on success, or a failure reason)

    /// Gets the user's current location and compares its distance to the target with `radius`.
    private func checkCoordinate(latitude: Double, longitude: Double, radius: Double) async -> String? {
        do {
            let userLocation = try await LocationTracker.currentLocation()
            let target = CLLocation(latitude: latitude, longitude: longitude)
            let distance = userLocation.distance(from: target)   // meters

            if distance <= radius { return nil }
            return "You're about \(Int(distance.rounded())) m away. Get within \(Int(radius.rounded())) m of the spot."
        } catch let error as LocationError {
            return error.message
        } catch {
            return "Couldn't get your location: \(error.localizedDescription)"
        }
    }

    /// Compares answers, ignoring case and surrounding whitespace.
    private func checkAnswer(attempt: String, answer: String) -> String? {
        let a = attempt.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = answer.trimmingCharacters(in: .whitespacesAndNewlines)

        if a.isEmpty { return "The answer is empty." }
        return a.caseInsensitiveCompare(b) == .orderedSame ? nil : "That answer isn't correct."
    }

    /// Compares images using Vision feature prints.
    ///
    /// - Parameter threshold: The maximum feature-print distance that counts as similar.
    ///   Lower distances mean more similar images. Tune it to taste.
    private func checkSimilarity(reference: Data, attempt: UIImage, threshold: Float = 0.5) -> String? {
        guard let referenceCG = UIImage(data: reference)?.cgImage else {
            return "The reference image is missing or corrupted."
        }
        guard let attemptCG = attempt.cgImage else {
            return "Couldn't read the photo you provided."
        }

        func featurePrint(for cgImage: CGImage) throws -> VNFeaturePrintObservation? {
            let request = VNGenerateImageFeaturePrintRequest()
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
            return request.results?.first
        }

        do {
            guard let a = try featurePrint(for: referenceCG),
                  let b = try featurePrint(for: attemptCG) else {
                return "Couldn't analyze the images."
            }
            var distance: Float = 0
            try a.computeDistance(&distance, to: b)
            return distance < threshold ? nil : "Your photo doesn't look similar enough to the target."
        } catch {
            return "Image comparison failed: \(error.localizedDescription)"
        }
    }
}
