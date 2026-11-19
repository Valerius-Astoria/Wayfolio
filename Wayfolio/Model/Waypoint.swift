//
//  Waypoint.swift
//  Wayfolio
//
//  Created by ZAKA on 11/19/26.
//

import MapKit
import SwiftData

@Model class Waypoint {
    var item: MKMapItem
    var icon: String
    var intro: String?
    var hours: Hours?
    var schedule: Schedule
    var isChecked: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \Clue.waypoint)
    var clues: [Clue]
    
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
         clues: [Clue] = [],
         hours: Hours? = nil,
         schedule: Schedule,
         isChecked: Bool = false) {
        self.item = item
        self.intro = intro
        self.clues = clues
        self.hours = hours
        self.schedule = schedule
        self.isChecked = isChecked
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
    init(latitude: Double,
         longitude: Double,
         name: String,
         phoneNumber: String?,
         fullAddress: String?,
         shortAddress: String?,
         url: URL?,
         icon: String = "mappin",
         intro: String?,
         clues: [Clue] = [],
         hours: Hours? = nil,
         isChecked: Bool = false) {
        item = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: MKAddress(fullAddress: fullAddress ?? "", shortAddress: shortAddress))
        item.phoneNumber = phoneNumber
        item.url = url
        self.intro = intro
        self.clues = clues
        self.hours = hours
        self.isChecked = isChecked
    }
    
    /// Marks the place as checked.
    func check() { self.isChecked = true }
    
    /// Checks if the place is currently open.
    ///
    /// - Returns: An optional boolean that shows whether the place is currently open, returns `nil` if the information is insufficient to determine.
    func isOpening() -> Bool? {
        hours?.isOpen()
    }
}

/// Stores a clue hidden in one place.
@Model class Clue {
    var name: String
    var brief: String
    var detail: String
    var icon: String
    var isChecked: Bool
    
    var waypoint: Waypoint
    
    init(name: String, brief: String, detail: String = "", icon: String = "folder", isChecked: Bool = false, waypoint: Waypoint) {
        self.name = name
        self.brief = brief
        self.detail = detail
        self.icon = icon
        self.isChecked = isChecked
        self.waypoint = waypoint
    }
    
    /// Marks the clue as checked.
    func check() { self.isChecked = true }
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
