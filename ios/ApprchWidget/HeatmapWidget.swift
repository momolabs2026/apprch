import AppIntents
import SwiftUI
import WidgetKit

struct HeatmapWidget: Widget {
    let kind = "ApprchHeatmapWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectTriggerIntent.self,
            provider: HeatmapTimelineProvider()
        ) { entry in
            HeatmapWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .configurationDisplayName("Trigger heatmap")
        .description("Keep a Trigger’s heatmap on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SelectTriggerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Trigger"
    static var description = IntentDescription("Choose which Trigger heatmap to show.")

    @Parameter(title: "Trigger")
    var trigger: TriggerEntity?
}

struct TriggerEntity: AppEntity, Identifiable, Hashable {
    var id: String
    var name: String
    var icon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Trigger"
    static var defaultQuery = TriggerEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(icon) \(name)")
    }

    init(id: String, name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }

    init(_ snapshot: WidgetTriggerSnapshot) {
        self.init(id: snapshot.id, name: snapshot.name, icon: snapshot.icon)
    }
}

struct TriggerEntityQuery: EntityQuery {
    func entities(for identifiers: [TriggerEntity.ID]) async throws -> [TriggerEntity] {
        WidgetSnapshotStore.load()
            .filter { identifiers.contains($0.id) }
            .map(TriggerEntity.init)
    }

    func suggestedEntities() async throws -> [TriggerEntity] {
        let preferred = WidgetSnapshotStore.preferredTriggerId
        return WidgetSnapshotStore.load()
            .sorted { lhs, rhs in
                if lhs.id == preferred { return true }
                if rhs.id == preferred { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map(TriggerEntity.init)
    }

    func defaultResult() async -> TriggerEntity? {
        WidgetSnapshotStore.snapshot(for: nil).map(TriggerEntity.init)
    }
}

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetTriggerSnapshot?
}

struct HeatmapTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HeatmapEntry {
        HeatmapEntry(date: Date(), snapshot: .placeholder)
    }

    func snapshot(for configuration: SelectTriggerIntent, in context: Context) async -> HeatmapEntry {
        HeatmapEntry(date: Date(), snapshot: WidgetSnapshotStore.snapshot(for: configuration.trigger?.id))
    }

    func timeline(for configuration: SelectTriggerIntent, in context: Context) async -> Timeline<HeatmapEntry> {
        let entry = HeatmapEntry(
            date: Date(),
            snapshot: WidgetSnapshotStore.snapshot(for: configuration.trigger?.id)
        )
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

extension WidgetTriggerSnapshot {
    static let placeholder = WidgetTriggerSnapshot(
        id: "placeholder",
        name: "Trigger",
        icon: "•",
        accentColorHex: "#2ECC71",
        countsByDay: [:],
        yearTotal: 0,
        todayCount: 0
    )
}
