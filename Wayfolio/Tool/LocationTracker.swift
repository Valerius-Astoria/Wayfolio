//
//  LocationTracker.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import CoreLocation

/// Provides the user's location as async sequences, built on `CLLocationUpdate.liveUpdates()`.
struct LocationTracker {
    /// Streams filtered location updates until the consuming task is cancelled or the stream is no longer iterated.
    ///
    /// Requires iOS 18+ (`CLServiceSession`) and `NSLocationWhenInUseUsageDescription` in Info.plist.
    /// Start it while the app is in the foreground.
    /// - Parameters:
    ///   - maxAccuracy: Fixes with a worse horizontal accuracy (in meters) are dropped.
    ///   - minimumDistance: A fix closer than this (in meters) to the last delivered one is dropped. Use `0` to deliver everything.
    ///   - inBackground: Keeps updates flowing while the app is backgrounded
    ///     (needs the "Location updates" background mode).
    /// - Returns: A stream of locations. It finishes with `LocationError.permissionDenied` if the user denies access.
    static func updates(
        maxAccuracy: CLLocationAccuracy = 50,
        minimumDistance: CLLocationDistance = 5,
        inBackground: Bool = true
    ) -> AsyncThrowingStream<CLLocation, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                // Both sessions live as long as this task does.
                let serviceSession = CLServiceSession(authorization: .whenInUse)
                let backgroundSession = inBackground ? CLBackgroundActivitySession() : nil
                defer {
                    backgroundSession?.invalidate()
                    serviceSession.invalidate()
                }

                var lastDelivered: CLLocation?

                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if Task.isCancelled { break }

                        if update.authorizationDenied || update.authorizationDeniedGlobally {
                            throw LocationError.permissionDenied
                        }

                        guard let location = update.location else { continue }
                        guard location.horizontalAccuracy >= 0,
                              location.horizontalAccuracy <= maxAccuracy else { continue }

                        if let last = lastDelivered, location.distance(from: last) < minimumDistance { continue }

                        lastDelivered = location
                        continuation.yield(location)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            // Stops tracking when the consumer cancels or stops iterating.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Returns the first location fix that is at least as accurate as `maxAccuracy` (in meters).
    ///
    /// - Throws: `LocationError.permissionDenied` if the user denies access,
    ///   or `LocationError.unavailable` if updates end without an acceptable fix.
    static func currentLocation(maxAccuracy: CLLocationAccuracy = 100) async throws -> CLLocation {
        for try await location in updates(maxAccuracy: maxAccuracy, minimumDistance: 0, inBackground: false) {
            return location   // leaving the loop terminates the stream and stops tracking
        }
        throw LocationError.unavailable
    }
}


/// Errors thrown by `LocationTracker`.
enum LocationError: LocalizedError {
    case permissionDenied
    case unavailable

    /// A user-facing explanation of the error.
    var message: String {
        switch self {
        case .permissionDenied: return "Location access is denied. Enable it in Settings."
        case .unavailable:      return "Your location is currently unavailable. Try again."
        }
    }

    var errorDescription: String? { message }
}
