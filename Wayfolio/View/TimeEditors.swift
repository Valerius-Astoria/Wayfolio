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

/// A page for editing a place's weekly opening hours.
///
/// One section: pick days at the top, and the controls below show and change the hours of those days.
/// Each day has at most one opening period here; editing a day replaces any others it had.
/// The footer summarizes the whole week.
struct HoursEditor: View {
    @Binding var hours: Hours

    /// The days the controls edit.
    @State private var selectedDays: Set<Hours.WeekDay>

    init(hours: Binding<Hours>) {
        _hours = hours
        // Start with the first group of days that share hours, such as Mon–Fri.
        let firstGroup = hours.wrappedValue.grouped().first { !$0.isClosed } ?? hours.wrappedValue.grouped().first
        _selectedDays = State(initialValue: Set(firstGroup?.days ?? []))
    }

    var body: some View {
        Form {
            Section {
                DaySelector(days: $selectedDays)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                Group {
                    Toggle("Open", isOn: isOpen)
                    if isOpen.wrappedValue {
                        Toggle("Open 24 hours", isOn: isAllDay)
                        if !isAllDay.wrappedValue {
                            HStack {
                                Text("Hours")
                                Spacer()
                                DatePicker("Opens", selection: Binding(hour: time(\.open, \.hour),
                                                                       minute: time(\.open, \.minute)),
                                           displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                Text("—")
                                DatePicker("Closes", selection: Binding(hour: time(\.close, \.hour),
                                                                        minute: time(\.close, \.minute)),
                                           displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .disabled(selectedDays.isEmpty)
            } header: {
                Text("Hours")
            } footer: {
                footer
            }
        }
        .navigationTitle("Hours")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: selectedDays)
    }

    // MARK: - Selected Days

    /// The selected days in calendar order.
    private var orderedSelection: [Hours.WeekDay] {
        Hours.WeekDay.calendarOrder.filter(selectedDays.contains)
    }

    /// The period the controls show: the first selected day's, or `nil` if that day is closed.
    private var shownPeriod: Hours.Period? {
        orderedSelection.first.flatMap { hours.periods(on: $0).first }
    }

    /// Whether the selected days don't all have the same hours, so editing will make them match.
    private var selectionDiffers: Bool {
        let times = orderedSelection.map { hours.periods(on: $0).map { [$0.open, $0.close] } }
        return Set(times).count > 1
    }

    /// Gives every selected day one period from `open` to `close`, or closes them all if `nil`.
    private func setSelectedDays(open: Hours.Time?, close: Hours.Time?) {
        var periods = hours.periods.filter { !selectedDays.contains($0.day) }
        if let open, let close {
            periods += orderedSelection.map { Hours.Period(day: $0, open: open, close: close) }
        }
        hours.periods = periods
    }

    // MARK: - Bindings

    private var isOpen: Binding<Bool> {
        Binding(
            get: { shownPeriod != nil },
            set: { isOpen in
                setSelectedDays(open: isOpen ? Hours.Time(9) : nil, close: isOpen ? Hours.Time(17) : nil)
            }
        )
    }

    /// Open 24 hours, stored as a period that opens and closes at midnight. See `Hours.Period.isAllDay`.
    private var isAllDay: Binding<Bool> {
        Binding(
            get: { shownPeriod?.isAllDay ?? false },
            set: { isAllDay in
                setSelectedDays(open: Hours.Time(isAllDay ? 0 : 9), close: Hours.Time(isAllDay ? 0 : 17))
            }
        )
    }

    /// The hour or minute of the shown period's opening or closing time. Setting it applies to every selected day.
    private func time(_ end: WritableKeyPath<Hours.Period, Hours.Time>,
                      _ component: WritableKeyPath<Hours.Time, Int>) -> Binding<Int> {
        Binding(
            get: { shownPeriod?[keyPath: end][keyPath: component] ?? 0 },
            set: { value in
                guard var period = shownPeriod else { return }
                period[keyPath: end][keyPath: component] = value
                setSelectedDays(open: period.open, close: period.close)
            }
        )
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectedDays.isEmpty {
                Text("Select days to edit their hours.")
            } else {
                if selectionDiffers {
                    Text("The selected days have different hours. Changes apply to all of them.")
                }
                if let shownPeriod, shownPeriod.isOvernight, !shownPeriod.isAllDay {
                    Text("Closes the next day.")
                }
            }
            // The whole week, so the effect of each edit is visible.
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                ForEach(hours.grouped()) { group in
                    GridRow {
                        Text(group.daysDisplay())
                        Text(group.hoursDisplay())
                            .foregroundStyle(group.isClosed ? .red : .secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
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
