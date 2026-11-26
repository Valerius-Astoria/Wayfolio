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
    private let modelContainer: ModelContainer

    init() {
        modelContainer = .wayfolio()
        modelContainer.seedSampleDataIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            MapScreen()
        }
        .modelContainer(modelContainer)
    }
}
