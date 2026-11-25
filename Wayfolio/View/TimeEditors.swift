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

/// A page for editing a place's weekly opening hours, modeled on the editor in Apple Maps.
///
/// Each card is one set of hours: the days it applies to and when it opens and closes.
/// A day can appear in several cards, such as for a lunch and a dinner service.
/// Days that aren't in any card are closed.
struct HoursEditor: View {
    @Binding var hours: Hours

    /// The cards being edited. Written back to `hours` as periods whenever they change.
    @State private var blocks: [HoursBlock]

    init(hours: Binding<Hours>) {
        _hours = hours
        _blocks = State(initialValue: HoursBlock.blocks(from: hours.wrappedValue))
    }

    var body: some View {
        Form {
            ForEach($blocks) { $block in
                Section {
                    DaySelector(days: $block.days)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    Toggle("Open 24 hours", isOn: $block.isAllDay)
                    if !block.isAllDay {
                        HStack {
                            Text("Hours")
                            Spacer()
                            DatePicker("Opens",
                                       selection: Binding(hour: $block.open.hour, minute: $block.open.minute),
                                       displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Text("—")
                            DatePicker("Closes",
                                       selection: Binding(hour: $block.close.hour, minute: $block.close.minute),
                                       displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                } header: {
                    HStack {
                        Text("Hours")
                        Spacer()
                        Button("Remove", role: .destructive) {
                            blocks.removeAll { $0.id == block.id }
                        }
                        .font(.footnote)
                        .textCase(nil)
                    }
                } footer: {
                    if block.isOvernight {
                        Text("Closes the next day.")
                    }
                }
            }
            Section {
                Button("Add Hours") {
                    blocks.append(HoursBlock(days: unusedDays, open: Hours.Time(9), close: Hours.Time(17)))
                }
            } footer: {
                Text("Days that aren't selected are closed.")
            }
        }
        .navigationTitle("Hours")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: blocks) {
            hours.periods = blocks.flatMap(\.periods)
        }
    }

    /// The days not selected in any card, which a new card starts with.
    private var unusedDays: Set<Hours.WeekDay> {
        Set(Hours.WeekDay.allCases).subtracting(blocks.flatMap(\.days))
    }
}

/// One card in `HoursEditor`: a set of days that share the same opening and closing time.
private struct HoursBlock: Identifiable, Equatable {
    let id = UUID()
    var days: Set<Hours.WeekDay>
    var open: Hours.Time
    var close: Hours.Time

    /// Open 24 hours, stored as a period that opens and closes at midnight. See `Hours.Period.isAllDay`.
    var isAllDay: Bool {
        get { open == close }
        set {
            open = Hours.Time(newValue ? 0 : 9)
            close = Hours.Time(newValue ? 0 : 17)
        }
    }

    /// Whether the hours end on the next day. See `Hours.Period.isOvernight`.
    var isOvernight: Bool { close < open }

    /// One period for each selected day.
    var periods: [Hours.Period] {
        Hours.WeekDay.calendarOrder
            .filter(days.contains)
            .map { Hours.Period(day: $0, open: open, close: close) }
    }

    /// Groups the periods in `hours` into cards, one for each distinct opening and closing time.
    static func blocks(from hours: Hours) -> [HoursBlock] {
        var blocks: [HoursBlock] = []
        for day in Hours.WeekDay.calendarOrder {
            for period in hours.periods(on: day) {
                if let index = blocks.firstIndex(where: { $0.open == period.open && $0.close == period.close }) {
                    blocks[index].days.insert(day)
                } else {
                    blocks.append(HoursBlock(days: [day], open: period.open, close: period.close))
                }
            }
        }
        return blocks
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
        .adding([.Fri, .Sat], open: .init(19), close: .init(2))
        .adding([.Sun], open: .init(0), close: .init(0))
    NavigationStack {
        HoursEditor(hours: $hours)
    }
}
