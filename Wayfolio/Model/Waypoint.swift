//
//  Waypoint.swift
//  Wayfolio
//
//  Created by ZAKA on 11/19/26.
//

import MapKit
import SwiftData

@Model class Waypoint {
    var name: String
    var latitude: Double
    var longitude: Double
    var poiIdentifier: String?
    var phoneNumber: String?
    var fullAddress: String?
    var shortAddress: String?
    var url: URL?
    var icon: String
    var intro: String?
    var hours: Hours?
    var schedule: Schedule
    var isChecked: Bool
    var condition: Condition = Condition.noCondition
    var order: Int
    
    @Relationship(deleteRule: .cascade, inverse: \Clue.waypoint)
    var clues: [Clue] = []
    var adventure: Adventure
    
    /// Initializer for a POI item.
    ///
    /// - Parameter item: An MKMapItem containing the latitude,longitude, name, phoneNumber, address, and url of a place.
    /// - Parameter intro: An introduction of the place.
    /// - Parameter clues: Clues hidden in the place.
    /// - Parameter hours: Opening hours of the place
    /// - Parameter day: The number of day to visit (Day1, Day2, etc.)
    /// - Parameter isChecked: Whether the placed has been checked by user, default to `false`.
    init(item: MKMapItem,
         intro: String?,
         hours: Hours? = nil,
         schedule: Schedule,
         isChecked: Bool = false,
         order: Int,
         adventure: Adventure) {
        self.name = item.name ?? "Unknown Place"
        self.latitude = item.location.coordinate.latitude
        self.longitude = item.location.coordinate.longitude
        self.poiIdentifier = item.identifier?.rawValue
        self.phoneNumber = item.phoneNumber
        self.fullAddress = item.address?.fullAddress
        self.shortAddress = item.address?.shortAddress
        self.url = item.url
        self.icon = "mappin"
        self.intro = intro
        self.hours = hours
        self.schedule = schedule
        self.isChecked = isChecked
        self.order = order
        self.adventure = adventure
    }
    
    /// Initializer for a custom place.
    ///
    /// - Parameter latitude: Latitude of the place.
    /// - Parameter longitude: Longitude of the place.
    /// - Parameter icon: Mark icon for the place,only available to custom places.
    /// - Parameter intro: An introduction of the place.
    /// - Parameter clues: Clues hidden in the place.
    /// - Parameter hours: Opening hours of the place
    /// - Parameter isChecked: Whether the placed has been checked by user, default to `false`.
    init(name: String,
         latitude: Double,
         longitude: Double,
         phoneNumber: String? = nil,
         fullAddress: String? = nil,
         shortAddress: String? = nil,
         url: URL? = nil,
         icon: String = "mappin",
         intro: String? = nil,
         hours: Hours? = nil,
         schedule: Schedule,
         isChecked: Bool,
         clues: [Clue] = [],
         order: Int,
         adventure: Adventure) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.phoneNumber = phoneNumber
        self.fullAddress = fullAddress
        self.shortAddress = shortAddress
        self.url = url
        self.icon = icon
        self.intro = intro
        self.hours = hours
        self.schedule = schedule
        self.isChecked = isChecked
        self.clues = clues
        self.order = order
        self.adventure = adventure
    }
    
    var isPOI: Bool { return poiIdentifier != nil }
    
    /// - Returns: The MKMapItem corresponding to the place. 
    func getMKMapItem() async -> MKMapItem? { await self.isPOI ? getPOIMKMapItem() : getCustomMKMapItem() }
    
    /// - Returns: the `MKMapItem` used to construct this waypoint, returns `nil` if it fails.
    private func getPOIMKMapItem() async -> MKMapItem? {
        guard let raw = poiIdentifier, let identifier = MKMapItem.Identifier(rawValue: raw) else { return nil }
        let request = MKMapItemRequest(mapItemIdentifier: identifier)
        return try? await request.mapItem
    }
    
    /// - Returns: the `MKMapItem` constructed from a custom place.
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
    
    /// `radius` is in meters.
    func addCoordinateCondition(latitude: Double, longitude: Double, radius: Double) {
        self.condition = .coordinate(latitude: latitude, longitude: longitude, radius: radius)
    }
    
    /// - Returns: `nil` if check is perfomed successfully (regardless of the checking result), returns the reason of error when it fails. 
    func check() async -> String? {
        if let errorMessage = await condition.check() {
            return errorMessage
        } else {
            isChecked = true
            return nil
        }
    }
    
    /// Checks if the place is currently open.
    ///
    /// - Returns: An optional boolean that shows whether the place is currently open, returns `nil` if the information is insufficient to determine.
    func isOpening() -> Bool? {
        hours?.isOpen()
    }
    
    func addClue(clue: Clue) {
        clues.append(clue)
    }
}

/// Stores a place's bussiness hours.
struct Hours: Codable {
    enum WeekDay: Int, Codable { case Sun = 1, Mon, Tue, Wed, Thu, Fri, Sat }
    
    let day: WeekDay
    var start: DateComponents?
    var end: DateComponents?
    
    /// Sets the bussiness hour to 24/7.
    mutating func set24() {
        self.start = DateComponents(hour: 0, minute: 0)
        self.end = DateComponents(hour: 23, minute: 59)
    }
    
    /// Checks if currently open.
    ///
    /// - Returns: An optional boolean that shows whether the place is currently open, returns `nil` if the information is insufficient to determine.
    func isOpen(at date: Date = .now) -> Bool? {
        let now = Calendar.current.dateComponents([.weekday, .hour, .minute], from: date)
        
        guard let weekday = now.weekday, weekday == day.rawValue,
              let startHour = start?.hour, let startMinute = start?.minute,
              let endHour = end?.hour, let endMinute = end?.minute,
              let currentHour = now.hour, let currentMinute = now.minute else {
            return nil
        }
        
        let startTotal = startHour * 60 + startMinute
        let endTotal = endHour * 60 + endMinute
        let currentTotal = currentHour * 60 + currentMinute
        
        // Handles both normal hours (9:00–17:00) and overnight hours (18:00–02:00)
        if startTotal <= endTotal {
            return (startTotal...endTotal).contains(currentTotal)
        } else {
            return currentTotal >= startTotal || currentTotal <= endTotal
        }
    }
}

/// Strores a planned time to visit a place.
struct Schedule: Codable {
    var day: Int
    var start: DateComponents
    var end: DateComponents
    
    /// - Parameter day: The number of day to visit (Day1, Day2, etc. ).
    init(startHour: Int, endHour: Int, startMinute: Int, endMinute: Int, on day: Int) {
        self.day = day
        self.start = DateComponents(hour: startHour, minute: startMinute)
        self.end = DateComponents(hour: endHour, minute: endMinute)
    }
}

enum WaypointCondition {
    case noCondition
    case coordinate(latitude: Double, longitude: Double, radius: Double)
}
