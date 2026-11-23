//
//  Waypoint.swift
//  Wayfolio
//
//  Created by ZAKA on 11/19/26.
//

import MapKit
import SwiftData

/// A place to visit during an adventure.
///
/// A waypoint is either a point of interest from Apple Maps (`isPOI`) or a custom place
/// created from raw coordinates.
@Model class Waypoint {
    var name: String
    var latitude: Double
    var longitude: Double
    /// The Apple Maps identifier, used to fetch fresh place details. `nil` for custom places.
    var poiIdentifier: String?
    var phoneNumber: String?
    var fullAddress: String?
    var shortAddress: String?
    var url: URL?
    /// An SF Symbol name for the map marker.
    var icon: String
    var brief: String
    var intro: String?
    var hours: Hours?
    var schedule: Schedule
    var isChecked: Bool
    /// What the user must do to check this waypoint. See `check()`.
    var condition: Condition = Condition.noCondition
    /// The position of this waypoint within its day.
    var order: Int
    var isEnd: Bool // An adventure is divided into multiple legs so users can stop for rest or meals. This variable indicates if the current waypoint is the end of a route segment (i.e., the start of a pointleg).


    @Relationship(deleteRule: .cascade, inverse: \Clue.waypoint)
    var clues: [Clue] = []
    var adventure: Adventure

    /// Creates a waypoint from an Apple Maps point of interest.
    ///
    /// The name, coordinates, phone number, address, and URL are copied from `item`.
    /// - Parameters:
    ///   - item: The map item to create the waypoint from.
    ///   - intro: An introduction to the place.
    ///   - hours: The place's opening hours.
    ///   - schedule: When the user plans to visit.
    ///   - isChecked: Whether the user has already checked the place.
    ///   - order: The position of this waypoint within its day.
    ///   - adventure: The adventure this waypoint belongs to.
    init(item: MKMapItem,
         intro: String?,
         brief: String,
         hours: Hours? = nil,
         schedule: Schedule,
         isChecked: Bool = false,
         order: Int,
         adventure: Adventure,
         isEnd: Bool) {
        self.name = item.name ?? "Unknown Place"
        self.latitude = item.location.coordinate.latitude
        self.longitude = item.location.coordinate.longitude
        self.poiIdentifier = item.identifier?.rawValue
        self.phoneNumber = item.phoneNumber
        self.fullAddress = item.address?.fullAddress
        self.shortAddress = item.address?.shortAddress
        self.url = item.url
        self.icon = "mappin"
        self.brief = brief
        self.intro = intro
        self.hours = hours
        self.schedule = schedule
        self.isChecked = isChecked
        self.order = order
        self.adventure = adventure
        self.isEnd = isEnd
    }

    /// Creates a custom waypoint that isn't an Apple Maps point of interest.
    ///
    /// - Parameters:
    ///   - icon: An SF Symbol name for the map marker. Only custom places can choose their icon.
    ///   - intro: An introduction to the place.
    ///   - hours: The place's opening hours.
    ///   - schedule: When the user plans to visit.
    ///   - isChecked: Whether the user has already checked the place.
    ///   - clues: Clues hidden at the place.
    ///   - order: The position of this waypoint within its day.
    ///   - adventure: The adventure this waypoint belongs to.
    init(name: String,
         latitude: Double,
         longitude: Double,
         phoneNumber: String? = nil,
         fullAddress: String? = nil,
         shortAddress: String? = nil,
         url: URL? = nil,
         icon: String = "mappin",
         intro: String? = nil,
         brief: String,
         hours: Hours? = nil,
         schedule: Schedule,
         isChecked: Bool = false,
         clues: [Clue] = [],
         order: Int,
         adventure: Adventure,
         isEnd: Bool) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.phoneNumber = phoneNumber
        self.fullAddress = fullAddress
        self.shortAddress = shortAddress
        self.url = url
        self.icon = icon
        self.intro = intro
        self.brief = brief
        self.hours = hours
        self.schedule = schedule
        self.isChecked = isChecked
        self.clues = clues
        self.order = order
        self.adventure = adventure
        self.isEnd = isEnd
    }

    /// Whether the waypoint comes from an Apple Maps point of interest.
    var isPOI: Bool { return poiIdentifier != nil }

    /// - Returns: A map item for the place, used for directions. `nil` if a POI can't be fetched.
    func getMKMapItem() async -> MKMapItem? { await self.isPOI ? getPOIMKMapItem() : getCustomMKMapItem() }

    /// Fetches the up-to-date map item from Apple Maps using `poiIdentifier`.
    ///
    /// - Returns: The map item, or `nil` if the identifier is missing or the request fails.
    private func getPOIMKMapItem() async -> MKMapItem? {
        guard let raw = poiIdentifier, let identifier = MKMapItem.Identifier(rawValue: raw) else { return nil }
        let request = MKMapItemRequest(mapItemIdentifier: identifier)
        return try? await request.mapItem
    }

    /// - Returns: A map item built from the stored coordinates and details.
    private func getCustomMKMapItem() -> MKMapItem {
        let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
        var address = self.fullAddress.flatMap { full in
            MKAddress(fullAddress: full, shortAddress: self.shortAddress)
        }

        let item = MKMapItem(location: location, address: address)
        item.phoneNumber = self.phoneNumber
        item.url = self.url

        return item
    }

    /// Requires the user to be within `radius` meters of the given coordinate to check this waypoint.
    func addCoordinateCondition(latitude: Double, longitude: Double, radius: Double) {
        self.condition = .coordinate(latitude: latitude, longitude: longitude, radius: radius)
    }

    /// Checks `condition` and marks the waypoint as checked if it's met.
    ///
    /// - Returns: `nil` if the condition is met, otherwise a message explaining why it isn't.
    func check() async -> String? {
        if let errorMessage = await condition.check() {
            return errorMessage
        } else {
            isChecked = true
            return nil
        }
    }

    /// Whether the place is open right now.
    ///
    /// - Returns: `nil` if there isn't enough information to tell. See `Hours.isOpen(at:)`.
    func isOpening() -> Bool? {
        hours?.isOpen()
    }

    func addClue(clue: Clue) {
        clues.append(clue)
    }
}

/// A place's opening hours on one day of the week.
///
/// Times are stored as minutes since midnight, because SwiftData can't store `DateComponents`.
struct Hours: Codable {
    /// Raw values match `Calendar`'s `weekday` component (Sunday is `1`).
    enum WeekDay: Int, Codable, CaseIterable { case Sun = 1, Mon, Tue, Wed, Thu, Fri, Sat }

    let day: WeekDay
    /// Opening time, in minutes since midnight.
    var startMinute: Int?
    var startHour: Int?
    /// Closing time, in minutes since midnight. May be earlier than `startMinute` for overnight hours.
    var endMinute: Int?
    var endHour: Int?

    /// Sets the hours to open all day.
    mutating func set24() {
        self.startMinute = 0
        self.endMinute = 24 * 60
    }

    /// Whether the place is open at `date`.
    ///
    /// Handles both normal hours (9:00–17:00) and overnight hours (18:00–02:00).
    /// - Returns: `nil` if `date` isn't on `day` or the opening or closing time is missing.
    func isOpen(at date: Date = .now) -> Bool? {
        let now = Calendar.current.dateComponents([.weekday, .hour, .minute], from: date)

        guard let weekday = now.weekday, weekday == day.rawValue,
              let startMinute = self.startMinute, let endMinute = self.endMinute,
              let startHour = self.startHour, let endHour = self.endHour,
              let currentHour = now.hour, let currentMinute = now.minute else {
            return nil
        }

        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        let currentMinutes = currentHour * 60 + currentMinute

        if startMinutes <= endMinutes {
            return (startMinutes...endMinutes).contains(currentMinutes)
        } else {
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
}

/// When the user plans to visit a place.
///
/// Times are stored as minutes since midnight, because SwiftData can't store `DateComponents`.
struct Schedule: Codable {
    /// The day of the adventure, starting from `1`.
    var day: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, on day: Int) {
        self.day = day
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }
    
    var startMinutes: Int {
        startHour * 60 + startMinute
    }
    
    var endMinutes: Int {
        endHour * 60 + endMinute
    }
}

enum WaypointCondition {
    case noCondition
    case coordinate(latitude: Double, longitude: Double, radius: Double)
}
