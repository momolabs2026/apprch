import SwiftUI
import WidgetKit

struct HeatmapWidgetView: View {
    var entry: HeatmapEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            content(snapshot)
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetTriggerSnapshot) -> some View {
        let accent = Color(hex: snapshot.accentColorHex)
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            HStack(spacing: 6) {
                Text(snapshot.icon)
                    .font(family == .systemSmall ? .title3 : .title2)
                Text(snapshot.name)
                    .font(family == .systemSmall ? .subheadline.weight(.semibold) : .headline)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            if family != .systemSmall {
                Text(yearLabel(snapshot.yearTotal))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HeatmapCanvas(
                counts: snapshot.countsByDay,
                accent: accent,
                weeksToShow: weeksToShow
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text(todayLabel(snapshot.todayCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snapshot.todayCount == 0 ? Color.secondary : accent)
                Spacer(minLength: 0)
                if family == .systemLarge {
                    legend(accent: accent)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.3x3")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open Apprch to load this heatmap")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var weeksToShow: Int {
        switch family {
        case .systemSmall: return 12
        case .systemMedium: return 20
        case .systemLarge: return 26
        default: return 20
        }
    }

    private func yearLabel(_ total: Int) -> String {
        total == 1 ? "1 time in the last year" : "\(total) times in the last year"
    }

    private func todayLabel(_ count: Int) -> String {
        switch count {
        case 0: return "Not yet"
        case 1: return "Done once today"
        default: return "Done \(count) times today"
        }
    }

    private func legend(accent: Color) -> some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.heatmapFill(level: level))
                    .frame(width: 8, height: 8)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct HeatmapCanvas: View {
    let counts: [String: Int]
    let accent: Color
    let weeksToShow: Int

    var body: some View {
        Canvas { context, size in
            let calendar = Calendar.current
            let days = HeatmapMath.daysInPastYear(calendar: calendar)
            let weeks = Array(days.chunked(into: 7).reversed().prefix(weeksToShow))
            guard !weeks.isEmpty else { return }

            let gap: CGFloat = max(1.5, min(3, size.width / 120))
            let cols = CGFloat(weeks.count)
            let rows: CGFloat = 7
            let cell = min(
                (size.width - gap * (cols - 1)) / max(cols, 1),
                (size.height - gap * (rows - 1)) / rows
            )
            guard cell > 1 else { return }

            let gridWidth = cols * cell + (cols - 1) * gap
            let gridHeight = rows * cell + (rows - 1) * gap
            let originX = max(0, (size.width - gridWidth) / 2)
            let originY = max(0, (size.height - gridHeight) / 2)
            let today = calendar.startOfDay(for: Date())
            let formatter = WidgetSharing.dayKeyFormatter
            let corner = max(1, cell * 0.22)

            for (col, week) in weeks.enumerated() {
                for (row, day) in week.enumerated() {
                    let key = formatter.string(from: calendar.startOfDay(for: day))
                    let count = counts[key] ?? 0
                    let rect = CGRect(
                        x: originX + CGFloat(col) * (cell + gap),
                        y: originY + CGFloat(row) * (cell + gap),
                        width: cell,
                        height: cell
                    )
                    let path = Path(roundedRect: rect, cornerRadius: corner, style: .continuous)
                    context.fill(path, with: .color(accent.heatmapFill(level: HeatmapMath.level(for: count))))
                    if calendar.startOfDay(for: day) == today {
                        context.stroke(path, with: .color(.primary.opacity(0.55)), lineWidth: max(0.8, cell * 0.08))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

enum HeatmapMath {
    static func level(for count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return 3
        default: return 4
        }
    }

    static func daysInPastYear(calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromWeekStart = (weekday - calendar.firstWeekday + 7) % 7
        guard let endOfWeek = calendar.date(byAdding: .day, value: 6 - daysFromWeekStart, to: today),
              let start = calendar.date(byAdding: .day, value: -(53 * 7 - 1), to: endOfWeek) else {
            return []
        }
        return (0..<(53 * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            r = 0.18; g = 0.8; b = 0.44
        }
        self.init(red: r, green: g, blue: b)
    }

    func heatmapFill(level: Int) -> Color {
        switch max(0, min(level, 4)) {
        case 0: return Color.secondary.opacity(0.16)
        case 1: return opacity(0.28)
        case 2: return opacity(0.5)
        case 3: return opacity(0.74)
        default: return opacity(1)
        }
    }
}

#Preview(as: .systemMedium) {
    HeatmapWidget()
} timeline: {
    HeatmapEntry(date: .now, snapshot: .placeholder)
}
