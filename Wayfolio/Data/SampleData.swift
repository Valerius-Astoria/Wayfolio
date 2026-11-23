//
//  SampleData.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import Foundation
import SwiftData
import SwiftUI

/// An in-memory SwiftData store filled with sample adventures, for previews and development.
@MainActor
class SampleData {
    static let shared = SampleData()

    /// The in-memory container. Pass it to `.modelContainer(_:)` in previews.
    let modelContainer: ModelContainer

    /// The container's main context.
    var context: ModelContext {
        modelContainer.mainContext
    }

    /// Creates the container and fills it with `Adventure.sampleData`. Crashes if the container can't be created.
    private init() {
        let schema = Schema([
            Adventure.self,
            Clue.self,
            PointLeg.self,
            Route.self,
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

extension Adventure {
    // MARK: - Sample Data

    /// Builds a two-day adventure in Yu Garden, Shanghai, with routes, waypoints, and a leg.
    ///
    /// The adventure isn't inserted into any context, so it's only suitable for previews
    /// that don't need SwiftData queries.
    static func createSampleAdventure() -> Adventure {
        let sample = Adventure(
            name: "达芬奇密码",
            brief: "An adventure we all like, an adventure we all admire.",
            intro: "This is a really cool adventure that brings you back to the laet centry. During this adventure, you'll visit the village tha t only exists in your imagination, rivers as clear as crystle, and status so vivid that you doubt if they are real.",
            notes: [
                Note(icon: "bus", body: "Remember to take buses as you can, taxies are expensive"),
                Note(icon: "umbrella", body: "Always bring an unbrella with you, it rains a lot")
            ],
            types: [.pilgrimage, .cityWalk],
            region: "Shanghai",
            tags: ["Sherlock Holmes", "Baker Street 221B"],
            image: UIImage(imageLiteralResourceName: "davinci_code").jpegData(compressionQuality: 0.8)!,
        )
        let route1 = Route(name: "豫园漫步", brief: "A morning stroll through Yu Garden.", intro: "Start at the heart of the lake and wander north through the garden's pavilions. There will be lakes, rocks, moise that truly attract you, making you want to write a poem for it.", on: 1, in: sample)
        let route2 = Route(name: "点春堂寻踪", brief: "A quiet visit to the Hall of Heralding Spring.", intro: "Return to the garden on the second day to explore the hall at your own pace.", on: 2, in: sample)
        let waypoint1 = Waypoint(name: "湖心庭", latitude: 31.226675990334833, longitude: 121.49190609513421, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 四牌楼", url: URL(string: "https://www.yugarden.com.cn/page/articleView/index.html"), intro: "5-acre garden built in 1577 that features Ming dynasty pavilions, ponds, rockeries & arched bridges.", brief: "A place with river and moist.", hours: Hours(day: .Sun, startMinute: 0, startHour: 9, endMinute: 30, endHour: 4), schedule: Schedule(startHour: 9, startMinute: 0, endHour: 10, endMinute: 30), isChecked: true, order: 0, route: route1)
        let waypoint2 = Waypoint(name: "元代铁狮", latitude: 31.22741726801741, longitude: 121.49205510793958, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 四牌楼", url: URL(string: "https://www.yugarden.com.cn/page/articleView/index.html"), intro: "5-acre garden built in 1577 that features Ming dynasty pavilions, ponds, rockeries & arched bridges.", brief: "A place with river and moist.", hours: Hours(day: .Sun, startMinute: 0, startHour: 9, endMinute: 30, endHour: 4), schedule: Schedule(startHour: 11, startMinute: 0, endHour: 12, endMinute: 15), isChecked: false, order: 1, route: route1)
        let waypoint3 = Waypoint(name: "点春堂", latitude: 31.227583553910062, longitude: 121.49233942208, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 四牌楼", url: URL(string: "https://www.yugarden.com.cn/page/articleView/index.html"), intro: "5-acre garden built in 1577 that features Ming dynasty pavilions, ponds, rockeries & arched bridges.", brief: "A place with river and moist.", hours: Hours(day: .Sun, startMinute: 0, startHour: 9, endMinute: 30, endHour: 4), schedule: Schedule(startHour: 9, startMinute: 30, endHour: 11, endMinute: 0), isChecked: false, order: 0, route: route2)
        route1.waypoints = [waypoint1, waypoint2]
        route2.waypoints = [waypoint3]
        let leg = PointLeg(startingPoint: waypoint1, endPoint: waypoint2, transportType: .walking, order: 0, route: route1)
        leg.expectedTravelTime = 12 * 60
        leg.distance = 850
        route1.pointLegs = [leg]
        sample.routes = [route1, route2]
        return sample
    }

    /// Adventures for previews, inserted by `SampleData`. They have no routes yet.
    static var sampleData: [Adventure] = [
        createSampleAdventure()
    ]
}
