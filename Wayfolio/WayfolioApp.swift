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
    var body: some Scene {
        WindowGroup {
//             Temporary: shows the sample adventure while the adventure view is being built.
            SearchSheet()
                .modelContainer(SampleData.shared.modelContainer)
//            NavigationStack {
//                ClueDetail(clue: Adventure.sampleData.first!.routes.first!.orderedWaypoints[1].clues.first { $0.order == 2 }!)
//            }
        }
    }
}
