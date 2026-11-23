//
//  WayfolioApp.swift
//  Wayfolio
//
//  Created by ZAKA on 11/19/26.
//

import SwiftUI
import SwiftData

@main
struct WayfolioApp: App {
    var body: some Scene {
        WindowGroup {
//            SearchSheet()
//                .modelContainer(SampleData.shared.modelContainer)
            NavigationStack {
                AdventureDetail(adventure: Adventure.createSampleAdventure())
            }
        }
    }
}
