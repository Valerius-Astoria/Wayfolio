//
//  TimeEditors.swift
//  Wayfolio
//
//  Created by ZAKA on 11/25/26.
//

import SwiftUI

extension Binding where Value == Date {
    /// A time of day today, for a `DatePicker` that shows only `.hourAndMinute`.
    ///
    /// Reads and writes the separate hour and minute values that `Schedule` and `Hours.Time` store.
    init(hour: Binding<Int>, minute: Binding<Int>) {
        self.init(
            get: {
                Calendar.current.date(bySettingHour: hour.wrappedValue,
                                      minute: minute.wrappedValue,
                                      second: 0,
                                      of: .now) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour.wrappedValue = components.hour ?? 0
                minute.wrappedValue = components.minute ?? 0
            }
        )
    }
}

/// Start and end pickers for a waypoint's visit.
///
/// The end can't be earlier than the start: moving the start past the end moves the end with it.
struct ScheduleEditor: View {
    @Binding var schedule: Schedule

    var body: some View {
        let start = Binding(hour: $schedule.startHour, minute: $schedule.startMinute)
        let end = Binding(hour: $schedule.endHour, minute: $schedule.endMinute)

        DatePicker("Start", selection: start, displayedComponents: .hourAndMinute)
            .onChange(of: schedule.startMinutes) {
                if schedule.endMinutes < schedule.startMinutes {
                    schedule.endHour = schedule.startHour
                    schedule.endMinute = schedule.startMinute
                }
            }
        DatePicker("End", selection: end, in: start.wrappedValue..., displayedComponents: .hourAndMinute)
    }
}

/// A page for editing a place's weekly opening hours: the days it is open and one opening period.
///
/// Days that aren't selected are closed.
struct HoursEditor: View {
    @Binding var hours: Hours

    @State private var days: Set<Hours.WeekDay>
    @State private var open: Hours.Time
    @State private var close: Hours.Time
    @State private var isAllDay: Bool

    init(hours: Binding<Hours>) {
        _hours = hours
        let periods = hours.wrappedValue.periods
        _days = State(initialValue: Set(periods.map(\.day)))
        _open = State(initialValue: periods.first?.open ?? Hours.Time(9))
        _close = State(initialValue: periods.first?.close ?? Hours.Time(17))
        _isAllDay = State(initialValue: periods.first?.isAllDay ?? false)
    }

    var body: some View {
        Form {
            Section {
                DaySelector(days: $days)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                Toggle("Open 24 hours", isOn: $isAllDay)
                if !isAllDay {
                    HStack {
                        Text("Hours")
                        Spacer()
                        DatePicker("Opens",
                                   selection: Binding(hour: $open.hour, minute: $open.minute),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("—")
                        DatePicker("Closes",
                                   selection: Binding(hour: $close.hour, minute: $close.minute),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            } footer: {
                if !isAllDay, close < open {
                    Text("Closes the next day.")
                } else {
                    Text("Days that aren't selected are closed.")
                }
            }
        }
        .navigationTitle("Hours")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: days, writeHours)
        .onChange(of: open, writeHours)
        .onChange(of: close, writeHours)
        .onChange(of: isAllDay, writeHours)
    }

    /// Writes one opening period for each selected day.
    private func writeHours() {
        let orderedDays = Hours.WeekDay.calendarOrder.filter(days.contains)
        let openTime = isAllDay ? Hours.Time(0) : open
        let closeTime = isAllDay ? Hours.Time(0) : close
        hours = Hours(orderedDays, open: openTime, close: closeTime)
    }
}

/// A row of round buttons, one per weekday, that turn each day on or off.
private struct DaySelector: View {
    @Binding var days: Set<Hours.WeekDay>

    var body: some View {
        HStack {
            ForEach(Hours.WeekDay.calendarOrder, id: \.self) { day in
                let isSelected = days.contains(day)
                Button {
                    if isSelected {
                        days.remove(day)
                    } else {
                        days.insert(day)
                    }
                } label: {
                    Text(day.initial)
                        .font(.subheadline.bold())
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(isSelected ? Color.accentColor : Color(.systemGray5)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                if day != Hours.WeekDay.calendarOrder.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private extension Hours.WeekDay {
    /// The localized full name, such as "Monday".
    var fullName: String { Calendar.current.weekdaySymbols[rawValue - 1] }

    /// The localized one-letter name, such as "M".
    var initial: String { Calendar.current.veryShortWeekdaySymbols[rawValue - 1] }
}

#Preview("Schedule") {
    @Previewable @State var schedule = Schedule(startHour: 9, startMinute: 0, endHour: 10, endMinute: 30)
    Form {
        ScheduleEditor(schedule: $schedule)
    }
}

#Preview("Hours") {
    @Previewable @State var hours = Hours([Hours.WeekDay].weekdays, open: .init(9), close: .init(17))
    NavigationStack {
        HoursEditor(hours: $hours)
    }
}
