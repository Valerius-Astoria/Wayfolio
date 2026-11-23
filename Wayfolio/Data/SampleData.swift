//
//  SampleData.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import Foundation
import SwiftData


/// An in-memory SwiftData store filled with sample adventures, for previews and development.
@MainActor
class SampleData {
    static let shared = SampleData()


    let modelContainer: ModelContainer


    /// The container's main context.
    var context: ModelContext {
        modelContainer.mainContext
    }


    private init() {
        let schema = Schema([
            Adventure.self,
            Clue.self,
            PointLeg.self,
            Waypoint.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)


        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            insertSampleData()
            try context.save()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    private func insertSampleData() {
        for adventure in Adventure.sampleData {
            context.insert(adventure)
        }
    }
}
