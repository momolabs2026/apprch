import SwiftUI

struct ContributionGraphView: View {
    let events: [TriggerEvent]
    let accent: Color

    private let cell: CGFloat = 16
    private let gap: CGFloat = 4

    var body: some View {
        let calendar = Calendar.current
        let days = Self.daysInPastYear(calendar: calendar)
        let counts = Self.countsByDay(events: events, calendar: calendar)
        let weeks = Array(days.chunked(into: 7).reversed())
        let total = days.reduce(0) { $0 + (counts[$1] ?? 0) }
        let today = calendar.startOfDay(for: Date())

        VStack(alignment: .leading, spacing: 12) {
            Text(total == 1 ? "1 time in the last year" : "\(total) times in the last year")
                .font(.subheadline.weight(.medium))

            HStack(alignment: .top, spacing: 8) {
                weekdayLabels
                    .padding(.top, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: gap) {
                        monthLabels(weeks: weeks, calendar: calendar)
                        HStack(alignment: .top, spacing: gap) {
                            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                                VStack(spacing: gap) {
                                    ForEach(week, id: \.self) { day in
                                        let dayStart = calendar.startOfDay(for: day)
                                        let count = counts[dayStart] ?? 0
                                        let isToday = dayStart == today
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(accent.heatmapFill(level: Self.level(for: count)))
                                            .frame(width: cell, height: cell)
                                            .overlay {
                                                if isToday {
                                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                        .strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5)
                                                }
                                            }
                                            .accessibilityLabel(Self.accessLabel(day: day, count: count))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Text("Less")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(accent.heatmapFill(level: level))
                            .frame(width: cell, height: cell)
                    }
                }
                Text("More")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: gap) {
            ForEach(0..<7, id: \.self) { index in
                Text(Self.weekdayName(index))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: cell)
                    .opacity(index % 2 == 1 ? 1 : 0)
            }
        }
    }

    private func monthLabels(weeks: [[Date]], calendar: Calendar) -> some View {
        HStack(alignment: .center, spacing: gap) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                let show = index == 0 || calendar.component(.month, from: week[0])
                    != calendar.component(.month, from: weeks[index - 1][0])
                Color.clear
                    .frame(width: cell, height: 16)
                    .overlay(alignment: .leading) {
                        if show {
                            Text(week[0].formatted(.dateTime.month(.abbreviated)))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                    }
            }
        }
    }

    private static func daysInPastYear(calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromWeekStart = (weekday - calendar.firstWeekday + 7) % 7
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6 - daysFromWeekStart, to: today),
              let start = calendar.date(byAdding: .day, value: -(53 * 7 - 1), to: endOfWeek) else {
            return []
        }
        return (0..<(53 * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private static func countsByDay(events: [TriggerEvent], calendar: Calendar) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.date)
            counts[day, default: 0] += 1
        }
        return counts
    }

    private static func level(for count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return 3
        default: return 4
        }
    }

    private static func weekdayName(_ index: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return symbols[(first + index) % 7]
    }

    private static func accessLabel(day: Date, count: Int) -> String {
        let date = day.formatted(.dateTime.month().day().year())
        if count == 0 { return "\(date), no activity" }
        return "\(date), \(count) \(count == 1 ? "time" : "times")"
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
