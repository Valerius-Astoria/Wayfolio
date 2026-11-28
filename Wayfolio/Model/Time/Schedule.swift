//
//  Schedule.swift
//  Wayfolio
//
//  Created by ZAKA on 11/24/26.
//


/// When the user plans to visit a place.
///
/// Times are stored as separate hour and minute values, because SwiftData can't store `DateComponents`.
struct Schedule: Codable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    /// Starts `delay` minutes after `schedule` ends, and lasts `duration` minutes.
    ///
    /// With no previous visit, the start is 9:00. Times stay on the same day (they do not wrap past 23:59).
    init(following schedule: Schedule?, delay: Int = 15, duration: Int = 30) {
        let startTotal = min((schedule?.endMinutes ?? 9 * 60 - delay) + delay, 23 * 60 + 59)
        let endTotal = min(startTotal + duration, 23 * 60 + 59)
        self.startHour = startTotal / 60
        self.startMinute = startTotal % 60
        self.endHour = endTotal / 60
        self.endMinute = endTotal % 60
    }

    /// The start time, in minutes since midnight.
    var startMinutes: Int {
        startHour * 60 + startMinute
    }

    /// The end time, in minutes since midnight.
    var endMinutes: Int {
        endHour * 60 + endMinute
    }

    /// How long the visit lasts, in minutes.
    var stayMinutes: Int {
        endMinutes - startMinutes
    }

    /// The time range formatted for display, such as `"9:05-10:30"`.
    func display() -> String {
        let startMinuteString = startMinute < 10 ? "0\(startMinute)" : "\(startMinute)"
        let endMinuteString = endMinute < 10 ? "0\(endMinute)" : "\(endMinute)"
        return("\(startHour):\(startMinuteString)-\(endHour):\(endMinuteString)")
    }
}