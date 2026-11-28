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

    /// Builds a two-day adventure around Yu Garden, Shanghai, with routes, waypoints, legs, and clues.
    ///
    /// The adventure isn't inserted into any context, so it's only suitable for previews
    /// that don't need SwiftData queries.
    static func createSampleAdventure() -> Adventure {
        let sample = Adventure(
            name: "达芬奇密码",
            brief: "An adventure we all like, an adventure we all admire.",
            intro: "This is a really cool adventure that brings you back to the late century. During this adventure, you'll visit the village that only exists in your imagination, rivers as clear as crystal, and statues so vivid that you doubt if they are real.",
            types: [.pilgrimage, .cityWalk],
            image: UIImage(imageLiteralResourceName: "davinci_code").jpegData(compressionQuality: 0.8),
        )
        sample.notes = [
            Note(icon: "bus", body: "Remember to take buses as you can, taxies are expensive"),
            Note(icon: "umbrella", body: "Always bring an umbrella with you, it rains a lot")
        ]
        let route1 = Route(name: "豫园漫步", brief: "A morning stroll through Yu Garden.", intro: "Start at the heart of the lake and wander north through the garden's pavilions. There will be lakes, rocks, moise that truly attract you, making you want to write a poem for it.", on: 1, in: sample)
        let route2 = Route(name: "点春堂寻踪", brief: "A quiet visit to the Hall of Heralding Spring.", intro: "Return to the garden on the second day to explore the hall at your own pace, then follow the trail south to the City God Temple and the old street.", on: 2, in: sample)

        let gardenURL = URL(string: "https://www.yugarden.com.cn/page/articleView/index.html")
        let gardenHours = Hours(open: .init(9), close: .init(16, 30))

        // MARK: Day 1

        let waypoint1 = Waypoint(name: "湖心亭", icon: "cup.and.saucer", intro: "A two-storey teahouse built in 1784 in the middle of the lake, one of the oldest teahouses in Shanghai.", schedule: Schedule(startHour: 9, startMinute: 0, endHour: 10, endMinute: 30), isChecked: true, latitude: 31.226675990334833, longitude: 121.49190609513421, phoneNumber: "+862163736950", fullAddress: "China, Shanghai, Huangpu, 豫园路257号", url: gardenURL, order: 0, route: route1)
        waypoint1.hours = Hours(.weekdays, open: .init(8, 30), close: .init(21)).adding(.weekend, open: .init(8), close: .init(21, 30))
        let waypoint2 = Waypoint(name: "九曲桥", icon: "water.waves", intro: "A zigzag bridge leading to the teahouse. Its turns are said to keep evil spirits away, as they can only travel in straight lines.", schedule: Schedule(startHour: 10, startMinute: 40, endHour: 11, endMinute: 0), latitude: 31.226453, longitude: 121.491538, fullAddress: "China, Shanghai, Huangpu, 豫园路", order: 1, route: route1)
        waypoint2.hours = .allDay
        let waypoint3 = Waypoint(name: "元代铁狮", intro: "A pair of iron lions cast in 1308 during the Yuan dynasty, guarding the gate in front of the Hall of Gathered Grace.", schedule: Schedule(startHour: 11, startMinute: 10, endHour: 12, endMinute: 15), latitude: 31.22741726801741, longitude: 121.49205510793958, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 安仁街218号", url: gardenURL, order: 2, route: route1)
        waypoint3.hours = gardenHours
        let waypoint4 = Waypoint(name: "南翔馒头店", icon: "fork.knife", intro: "Serving soup dumplings by the lake since 1900. Expect a queue at the takeaway window.", schedule: Schedule(startHour: 12, startMinute: 30, endHour: 13, endMinute: 30), latitude: 31.226198, longitude: 121.491362, phoneNumber: "+862163554206", fullAddress: "China, Shanghai, Huangpu, 豫园路85号", order: 3, route: route1)
        waypoint4.hours = Hours(.weekdays, open: .init(10), close: .init(14)).adding(.weekdays, open: .init(16, 30), close: .init(21)).adding(.weekend, open: .init(10), close: .init(21))

        // MARK: Day 2

        let waypoint5 = Waypoint(name: "点春堂", intro: "Built in 1820, the hall served as the headquarters of the Small Swords Society during their 1853 uprising.", schedule: Schedule(startHour: 9, startMinute: 30, endHour: 11, endMinute: 0), latitude: 31.227583553910062, longitude: 121.49233942208, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 安仁街218号", url: gardenURL, order: 0, route: route2)
        waypoint5.hours = gardenHours
        let waypoint6 = Waypoint(name: "玉玲珑", icon: "mountain.2", intro: "One of the three great rocks of Jiangnan. Light an incense below and the smoke rises out of every hole at once.", schedule: Schedule(startHour: 11, startMinute: 15, endHour: 12, endMinute: 0), latitude: 31.228012, longitude: 121.492781, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 安仁街218号", url: gardenURL, order: 1, route: route2)
        waypoint6.hours = gardenHours
        let waypoint7 = Waypoint(name: "上海城隍庙", icon: "building.columns", intro: "A Taoist temple first built in the Ming dynasty, dedicated to the city's guardian gods.", schedule: Schedule(startHour: 13, startMinute: 0, endHour: 14, endMinute: 30), latitude: 31.225336, longitude: 121.490502, phoneNumber: "+862163865700", fullAddress: "China, Shanghai, Huangpu, 方浜中路249号", url: URL(string: "https://www.shchm.org"), order: 2, route: route2)
        waypoint7.hours = Hours([.Tue, .Wed, .Thu, .Fri, .Sat, .Sun], open: .init(8, 30), close: .init(16, 30))
        let waypoint8 = Waypoint(name: "上海老街", icon: "storefront", intro: "A restored street of Ming and Qing style shopfronts selling snacks, tea, and antiques.", schedule: Schedule(startHour: 14, startMinute: 45, endHour: 16, endMinute: 30), latitude: 31.224617, longitude: 121.489316, fullAddress: "China, Shanghai, Huangpu, 方浜中路", order: 3, route: route2)
        waypoint8.hours = Hours([.Sun, .Mon, .Tue, .Wed, .Thu], open: .init(9), close: .init(21)).adding([.Fri, .Sat], open: .init(9), close: .init(0, 30))

        // MARK: Clues
        
        waypoint1.clues = [
            Clue(clueName: "The Saucer", brief: "Order a pot of tea and look beneath the saucer.", detail: "\"Cross the water, but never in a straight line.\"", icon: "envelope", waypoint: waypoint1, order: 0),
            Clue(clueName: "Upstairs Window", brief: "Find the window that faces the bridge.", detail: "From up here, count the bridge's turns before you leave.", icon: "binoculars", location: LocationCondition(latitude: 31.226675990334833, longitude: 121.49190609513421, radius: 50), waypoint: waypoint1, order: 1)
        ]
        waypoint2.clues = [
            Clue(clueName: "Count the Turns", brief: "Walk the bridge from end to end.", detail: "The number unlocks the lions' riddle.", icon: "number", question: QuestionCondition(question: "How many turns does the bridge make?", answer: "9", hint: "It's right there in the bridge's Chinese name, 九曲桥."), waypoint: waypoint2, order: 0),
            Clue(clueName: "Count the Turns", brief: "Walk the bridge from end to end.", detail: "The number unlocks the lions' riddle.", icon: "number", photo: PhotoCondition(name: "Apple", reference: UIImage(named: "apple")!, threshold: 0.5), waypoint: waypoint2, order: 1),
            Clue(clueName: "Master of the Bridge", brief: "Prove you've truly crossed the bridge.", detail: "Only those who walk every turn may enter the garden's heart.", icon: "star", location: LocationCondition(latitude: 31.226453, longitude: 121.491538, radius: 40), photo: UIImage(named: "apple").flatMap { PhotoCondition(name: "Apple", reference: $0) }, question: QuestionCondition(question: "What does the teahouse float on?", answer: "lake", hint: "Look down from the bridge."), waypoint: waypoint2, order: 2),
        ]
        waypoint3.clues = [
            Clue(clueName: "The Lions' Age", brief: "Read the plaque beside the lions.", detail: "Older than the garden, they have watched every visitor pass. Next, follow your stomach to the lake.", icon: "pawprint", question: QuestionCondition(question: "Which dynasty cast these lions?", answer: "Yuan", hint: "The dynasty founded by Kublai Khan."), waypoint: waypoint3, order: 0),
            Clue(clueName: "At the Gate", brief: "Stand between the two lions.", detail: "One lion holds a ball, the other a cub. Together they guard the garden.", icon: "location", location: LocationCondition(latitude: 31.22741726801741, longitude: 121.49205510793958, radius: 30), waypoint: waypoint3, order: 1)
        ]
        waypoint4.clues = [
            Clue(clueName: "Eighteen Folds", brief: "Look closely before the first bite.", detail: "Tomorrow, the answer hides in the hall where spring is heralded.", icon: "fork.knife", question: QuestionCondition(question: "How many pleats does a perfect dumpling have?", answer: "18", hint: "Twice the number of turns on the bridge."), waypoint: waypoint4, order: 0)
        ]
        waypoint5.clues = [
            Clue(clueName: "The Rebels' Hall", brief: "Step inside the hall.", detail: "\"The rebels hid their messages among the rocks. Find the one that breathes smoke.\"", icon: "scroll", location: LocationCondition(latitude: 31.227583553910062, longitude: 121.49233942208, radius: 40), waypoint: waypoint5, order: 0)
        ]
        waypoint6.clues = [
            Clue(clueName: "Seventy-Two Holes", brief: "Count them if you dare.", detail: "Every hole is a way out. Head south, where the city's guardians keep watch.", icon: "circle.grid.3x3", question: QuestionCondition(question: "How many holes does the rock have, by legend?", answer: "72", hint: "The same number as the Monkey King's transformations."), waypoint: waypoint6, order: 0)
        ]
        waypoint7.clues = [
            Clue(clueName: "The Orb", brief: "A riddle from the Grail's keepers.", detail: "Now find one on the old street.", icon: "questionmark.circle", question: QuestionCondition(question: "You seek the orb that ought to be on Newton's tomb.", answer: "apple", hint: "Five letters. One fell on Newton's head."), waypoint: waypoint7, order: 0)
        ]
        waypoint8.clues = [
            Clue(clueName: "Find the Orb", brief: "Take a photo of an apple at a fruit stall.", detail: "The adventure is complete. The Grail was never far away.", icon: "camera", photo: UIImage(named: "apple").flatMap { PhotoCondition(name: "Apple", reference: $0) }, waypoint: waypoint8, order: 0)
        ]

        route1.waypoints = [waypoint1, waypoint2, waypoint3, waypoint4]
        route2.waypoints = [waypoint5, waypoint6, waypoint7, waypoint8]

        // MARK: Legs

        func leg(_ from: Waypoint, _ to: Waypoint, minutes: Double, meters: Double, order: Int, route: Route) -> PointLeg {
            let leg = PointLeg(startingPoint: from, endPoint: to, transportType: .walking, order: order, route: route)
            leg.expectedTravelTime = minutes * 60
            leg.distance = meters
            return leg
        }
        route1.pointLegs = [
            leg(waypoint1, waypoint2, minutes: 2, meters: 60, order: 0, route: route1),
            leg(waypoint2, waypoint3, minutes: 8, meters: 450, order: 1, route: route1),
            leg(waypoint3, waypoint4, minutes: 10, meters: 550, order: 2, route: route1)
        ]
        route2.pointLegs = [
            leg(waypoint5, waypoint6, minutes: 5, meters: 250, order: 0, route: route2),
            leg(waypoint6, waypoint7, minutes: 12, meters: 700, order: 1, route: route2),
            leg(waypoint7, waypoint8, minutes: 4, meters: 200, order: 2, route: route2)
        ]
        sample.routes = [route1, route2]
        return sample
    }

    /// Adventures for previews, inserted by `SampleData`.
    static var sampleData: [Adventure] {
        [createSampleAdventure()]
    }
}
