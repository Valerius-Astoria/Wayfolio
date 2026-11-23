//
//  Adventure.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import SwiftData
import CoreLocation
internal import System

/// A multi-day trip made up of waypoints to visit and the legs that connect them.
@Model class Adventure {
    var name: String
    /// A one-line summary shown in lists.
    var brief: String
    /// The full introduction shown on the detail page.
    var intro: String
    /// Practical tips for the trip, such as transport or weather advice.
    var notes: [Note] = []
    /// The path the user actually walked, recorded by `track(maxAccuracy:minimumDistance:)`.
    var trace: [RouteCoordinate] = []
    var types: [AdventureType] = []
    var status: Status = Status.notStarted
    /// The city or area where the adventure takes place, such as "Shanghai".
    var region: String
    /// Free-form keywords used by `search(query:in:)`, such as the book or movie it's based on.
    var tags: [String] = []

    @Attribute(.externalStorage)
    var image: Data
    @Relationship(deleteRule: .cascade, inverse: \Waypoint.adventure)
    var waypoints: [Waypoint] = []
    @Relationship(deleteRule: .cascade, inverse: \PointLeg.adventure)
    var pointLegs: [PointLeg] = []

    init(name: String, brief: String, intro: String, notes: [Note] = [], types: [AdventureType] = [], region: String, tags: [String], image: Data) {
        self.name = name
        self.brief = brief
        self.intro = intro
        self.notes = notes
        self.types = types
        self.region = region
        self.tags = tags
        self.image = image
    }

    /// The number of days the adventure lasts, taken from the highest `day` among its waypoints.
    ///
    /// `0` if there are no waypoints.
    var dayCount: Int {
        waypoints.map { $0.schedule.day }.max() ?? 0
    }

    /// Whether the adventure is complete, meaning every waypoint is checked.
    ///
    /// `true` for an adventure with no waypoints.
    var isChecked: Bool {
        waypoints.allSatisfy { $0.isChecked }
    }

    /// The days that have at least one waypoint, in ascending order.
    var days: [Int] {
        Set(waypoints.map(\.schedule.day)).sorted()
    }

    /// Tracks the user's location during the adventure and appends each point to `trace`.
    ///
    /// Runs until the surrounding `Task` is cancelled. Existing `trace` points are kept,
    /// so tracking can be stopped and resumed (for example across days).
    /// - Parameters:
    ///   - maxAccuracy: Location fixes less accurate than this (in meters) are ignored.
    ///   - minimumDistance: Points closer than this (in meters) to the previous one are ignored.
    /// - Throws: `LocationError.permissionDenied` if the user denies location access.
    @MainActor
    func track(maxAccuracy: CLLocationAccuracy = 50, minimumDistance: CLLocationDistance = 10) async throws {
        for try await location in LocationTracker.updates(maxAccuracy: maxAccuracy,
                                                          minimumDistance: minimumDistance) {
            trace.append(RouteCoordinate(location.coordinate))
        }
    }

    /// - Returns: The waypoints scheduled on `day`, sorted by `order`.
    func waypoints(on day: Int) -> [Waypoint] {
        waypoints
            .filter { $0.schedule.day == day }
            .sorted { $0.order < $1.order }
    }

    /// - Returns: The leg that departs from `waypoint`, or `nil` if it's the last stop.
    func leg(from waypoint: Waypoint) -> PointLeg? {
        pointLegs.first { $0.startingPoint == waypoint }
    }

    // MARK: - Search

    /// Finds the adventures that match `query`.
    ///
    /// Matching ignores case and diacritics. Results are ranked by where the match was found:
    /// name, then tags, then region. Adventures with the same rank are sorted by name.
    /// - Returns: The matching adventures, or all of `adventures` if `query` is blank.
    static func search(query: String, in adventures: [Adventure]) -> [Adventure] {
          let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !query.isEmpty else { return adventures }

          let matches: [(adventure: Adventure, rank: Int)] = adventures.compactMap { adventure in
              guard let rank = adventure.searchRank(for: query) else { return nil }
              return (adventure, rank)
          }

          return matches
              .sorted { lhs, rhs in
                  if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                  return lhs.adventure.name.localizedStandardCompare(rhs.adventure.name) == .orderedAscending
              }
              .map(\.adventure)
      }

    /// - Returns: `0` for a name match, `1` for a tag match, `2` for a region match,
    ///   or `nil` if nothing matches. Lower is better.
    private func searchRank(for query: String) -> Int? {
        if name.localizedStandardContains(query) { return 0 }
        if tags.contains(where: { $0.localizedStandardContains(query)} ) { return 1 }
        if region.localizedStandardContains(query) { return 2 }
        return nil
    }

    // MARK: - Sample Data
    
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
        let waypoint1 = Waypoint(name: "湖心庭", latitude: 31.226675990334833, longitude: 121.49190609513421, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 四牌楼", url: URL("https://www.yugarden.com.cn/page/articleView/index.html"), intro: "5-acre garden built in 1577 that features Ming dynasty pavilions, ponds, rockeries & arched bridges.", brief: "A place with river and moist.", hours: Hours(day: .Sun, startMinute: 0, startHour: 9, endMinute: 30, endHour: 4), schedule: Schedule(startHour: 9, startMinute: 0, endHour: 10, endMinute: 30, on: 1), isChecked: true, order: 0, adventure: sample, isEnd: false)
        let waypoint2 = Waypoint(name: "元代铁狮", latitude: 31.22741726801741, longitude: 121.49205510793958, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 四牌楼", url: URL("https://www.yugarden.com.cn/page/articleView/index.html"), intro: "5-acre garden built in 1577 that features Ming dynasty pavilions, ponds, rockeries & arched bridges.", brief: "A place with river and moist.", hours: Hours(day: .Sun, startMinute: 0, startHour: 9, endMinute: 30, endHour: 4), schedule: Schedule(startHour: 11, startMinute: 0, endHour: 12, endMinute: 15, on: 1), isChecked: false, order: 1, adventure: sample, isEnd: true)
        let waypoint3 = Waypoint(name: "点春堂", latitude: 31.227583553910062, longitude: 121.49233942208, phoneNumber: "+862163260830", fullAddress: "China, Shanghai, Huangpu, 四牌楼", url: URL("https://www.yugarden.com.cn/page/articleView/index.html"), intro: "5-acre garden built in 1577 that features Ming dynasty pavilions, ponds, rockeries & arched bridges.", brief: "A place with river and moist.", hours: Hours(day: .Sun, startMinute: 0, startHour: 9, endMinute: 30, endHour: 4), schedule: Schedule(startHour: 9, startMinute: 30, endHour: 11, endMinute: 0, on: 2), isChecked: false, order: 0, adventure: sample, isEnd: true)
        sample.waypoints = [waypoint1, waypoint2, waypoint3]
        let leg = PointLeg(startingPoint: waypoint1, endPoint: waypoint2, transportType: .walking, order: 0, adventure: sample)
        leg.expectedTravelTime = 12 * 60
        sample.pointLegs = [leg]
        return sample
    }

    /// Adventures for previews, inserted by `SampleData`.
    static let sampleData: [Adventure] = [
        Adventure(
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
            image: UIImage(imageLiteralResourceName: "davinci_code").jpegData(compressionQuality: 0.8)!
        )
    ]
}

/// A short tip attached to an adventure.
struct Note: Codable, Identifiable {
    var id: UUID = UUID()

    /// An SF Symbol name.
    var icon: String
    var body: String
}

/// The user's progress through an adventure.
enum Status: String, Codable {
    case notStarted, stared, ended, abondened
}
