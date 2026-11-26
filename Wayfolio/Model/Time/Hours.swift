//
//  Hours.swift
//  Wayfolio
//
//  Created by ZAKA on 11/23/26.
//

import Foundation

/// A place's weekly opening hours.
///
/// Each day can have several periods, such as a morning and an evening with a break between them,
/// and a period can run past midnight. A day with no periods is closed.
nonisolated struct Hours: Codable {
    /// Raw values match `Calendar`'s `weekday` component (Sunday is `1`).
    nonisolated enum WeekDay: Int, Codable, CaseIterable {
        case Sun = 1, Mon, Tue, Wed, Thu, Fri, Sat

        /// The localized short name, such as "Mon".
        var shortName: String { Calendar.current.shortWeekdaySymbols[rawValue - 1] }

        /// The day before this one.
        var previous: WeekDay { WeekDay(rawValue: (rawValue + 5) % 7 + 1)! }

        /// All days, starting from the current calendar's first weekday.
        static var calendarOrder: [WeekDay] {
            let first = Calendar.current.firstWeekday
            return (0..<7).map { WeekDay(rawValue: (first - 1 + $0) % 7 + 1)! }
        }
    }

    /// A time of day.
    ///
    /// Stored as separate hour and minute values, because SwiftData can't store `DateComponents`.
    nonisolated struct Time: Codable, Hashable, Comparable {
        /// From `0` to `23`.
        var hour: Int
        /// From `0` to `59`.
        var minute: Int

        init(_ hour: Int, _ minute: Int = 0) {
            self.hour = hour
            self.minute = minute
        }

        /// Minutes since midnight.
        var minutes: Int { hour * 60 + minute }

        static func < (lhs: Time, rhs: Time) -> Bool { lhs.minutes < rhs.minutes }

        /// The time formatted for display, such as `"9:05"`.
        func display() -> String { String(format: "%d:%02d", hour, minute) }
    }

    /// A span of time on one day when the place is open.
    nonisolated struct Period: Codable, Hashable {
        let day: WeekDay
        var open: Time
        /// If this isn't after `open`, the period ends on the next day, so `open == close` means open 24 hours.
        var close: Time

        /// Whether the period ends on the next day.
        var isOvernight: Bool { close <= open }

        /// Whether the place is open for 24 hours from `open`.
        var isAllDay: Bool { open == close }

        /// The period formatted for display, such as `"9:00–17:00"`.
        func display() -> String {
            isAllDay ? "Open 24 hours" : "\(open.display())–\(close.display())"
        }
    }

    /// Days that share the same opening times, for display.
    nonisolated struct Group: Identifiable {
        /// In calendar order.
        let days: [WeekDay]
        /// The opening periods of the first day. The other days have the same times.
        let periods: [Period]

        var id: WeekDay { days[0] }

        var isClosed: Bool { periods.isEmpty }

        /// The days formatted for display, such as `"Mon–Fri, Sun"`.
        ///
        /// Three or more consecutive days are joined with a dash.
        func daysDisplay() -> String {
            if days.count == 7 { return "Every day" }

            let order = WeekDay.calendarOrder
            var runs: [[WeekDay]] = []
            for day in days {
                if let last = runs.last?.last,
                   order.firstIndex(of: day) == order.firstIndex(of: last)! + 1 {
                    runs[runs.count - 1].append(day)
                } else {
                    runs.append([day])
                }
            }

            return runs.flatMap { run in
                run.count >= 3 ? ["\(run.first!.shortName)–\(run.last!.shortName)"] : run.map(\.shortName)
            }
            .joined(separator: ", ")
        }

        /// The opening periods formatted for display, one per line, or `"Closed"`.
        func hoursDisplay() -> String {
            isClosed ? "Closed" : periods.map { $0.display() }.joined(separator: "\n")
        }
    }

    var periods: [Period]

    init(periods: [Period] = []) {
        self.periods = periods
    }

    /// Creates hours where every day in `days` has the same opening period.
    ///
    /// Days not in `days` are closed. Add more periods with `adding(_:open:close:)`.
    init(_ days: [WeekDay] = WeekDay.allCases, open: Time, close: Time) {
        self.periods = days.map { Period(day: $0, open: open, close: close) }
    }

    /// Hours that are open 24 hours every day.
    static let allDay = Hours(open: Time(0), close: Time(0))

    /// - Returns: A copy with an opening period added to every day in `days`.
    func adding(_ days: [WeekDay], open: Time, close: Time) -> Hours {
        Hours(periods: periods + days.map { Period(day: $0, open: open, close: close) })
    }

    /// The opening periods on `day`, sorted by opening time.
    func periods(on day: WeekDay) -> [Period] {
        periods
            .filter { $0.day == day }
            .sorted { $0.open < $1.open }
    }

    /// Whether the place is open at `date`.
    ///
    /// Includes periods that started the day before and run past midnight.
    func isOpen(at date: Date = .now) -> Bool {
        let components = Calendar.current.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday.flatMap(WeekDay.init(rawValue:)),
              let hour = components.hour, let minute = components.minute else {
            return false
        }
        let now = hour * 60 + minute

        let openFromToday = periods(on: weekday).contains { period in
            period.isOvernight
                ? now >= period.open.minutes
                : (period.open.minutes..<period.close.minutes).contains(now)
        }
        let openFromYesterday = periods(on: weekday.previous).contains { period in
            period.isOvernight && now < period.close.minutes
        }
        return openFromToday || openFromYesterday
    }

    /// Days with the same opening times grouped together, in the order their first day appears in the week.
    ///
    /// For example, a place open 9:00–17:00 on weekdays and closed at weekends gives
    /// `Mon–Fri 9:00–17:00` and `Sat, Sun Closed`.
    func grouped() -> [Group] {
        var groups: [(days: [WeekDay], periods: [Period])] = []

        for day in WeekDay.calendarOrder {
            let dayPeriods = periods(on: day)
            let times = dayPeriods.map { [$0.open, $0.close] }
            if let index = groups.firstIndex(where: { $0.periods.map { [$0.open, $0.close] } == times }) {
                groups[index].days.append(day)
            } else {
                groups.append((days: [day], periods: dayPeriods))
            }
        }

        return groups.map { Group(days: $0.days, periods: $0.periods) }
    }
}

extension [Hours.WeekDay] {
    /// Monday to Friday.
    static var weekdays: [Hours.WeekDay] { [.Mon, .Tue, .Wed, .Thu, .Fri] }
    /// Saturday and Sunday.
    static var weekend: [Hours.WeekDay] { [.Sat, .Sun] }
}
