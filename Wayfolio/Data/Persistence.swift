//
//  Persistence.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import Foundation
import OSLog
import SwiftData

extension Schema {
    /// Every model the app stores.
    static let wayfolio = Schema([
        Adventure.self,
        Clue.self,
        PointLeg.self,
        Route.self,
        Waypoint.self
    ])
}

extension ModelContainer {
    /// The app's on-disk store.
    ///
    /// If the store can't be opened, falls back to an in-memory one so the app still launches,
    /// and logs the error.
    @MainActor
    static func wayfolio() -> ModelContainer {
        do {
            return try ModelContainer(for: .wayfolio, configurations: ModelConfiguration(schema: .wayfolio))
        } catch {
            Logger.persistence.error("Couldn't open the store, using a temporary one: \(error)")
            do {
                return try ModelContainer(for: .wayfolio,
                                          configurations: ModelConfiguration(schema: .wayfolio, isStoredInMemoryOnly: true))
            } catch {
                fatalError("Couldn't create an in-memory store: \(error)")
            }
        }
    }

    /// Inserts the sample adventure on the first launch only, so deleting it doesn't bring it back.
    ///
    /// Remove this along with `SampleData.swift` once the sample isn't needed.
    @MainActor
    func seedSampleDataIfNeeded(defaults: UserDefaults = .standard) {
        let key = "didSeedSampleData"
        guard !defaults.bool(forKey: key) else { return }
        mainContext.insert(Adventure.createSampleAdventure())
        do {
            try mainContext.save()
            defaults.set(true, forKey: key)
        } catch {
            Logger.persistence.error("Couldn't save the sample data: \(error)")
        }
    }
}

extension Logger {
    static let persistence = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Wayfolio", category: "Persistence")
}
