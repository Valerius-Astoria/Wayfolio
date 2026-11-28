//
//  WayfolioApp.swift
//  Wayfolio
//
//  Created by ZAKA on 11/19/26.
//

import SwiftUI
import SwiftData

/// The app's entry point.
@main
struct WayfolioApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            Adventure.self,
            Clue.self,
            PointLeg.self,
            Route.self,
            Waypoint.self
        ])
        let storeURL = URL.applicationSupportDirectory.appending(path: "Wayfolio.store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // If a schema change cannot load the existing store, delete
            // Application Support/Wayfolio.store (and -wal/-shm) locally, then relaunch.
            fatalError("Could not create ModelContainer: \(error)")
        }
        Self.seedIfEmpty(modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            MapView(mapModel: MapModel())
        }
        .modelContainer(modelContainer)
    }

    /// Inserts the sample adventure the first time the on-disk store is empty.
    private static func seedIfEmpty(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Adventure>())) ?? 0
        guard count == 0 else { return }
        for adventure in Adventure.sampleData {
            context.insert(adventure)
        }
        try? context.save()
    }
}
