import Foundation
import WidgetKit

enum WidgetSharing {
    static let appGroupID = "group.com.momo-labs.Apprch"
    static let snapshotsKey = "widget.snapshots"
    static let preferredTriggerKey = "widget.preferredTriggerId"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct WidgetTriggerSnapshot: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var icon: String
    var accentColorHex: String
    var countsByDay: [String: Int]
    var yearTotal: Int
    var todayCount: Int
}

struct WidgetSnapshotPayload: Codable {
    var triggers: [WidgetTriggerSnapshot]
}

enum WidgetSnapshotStore {
    static func load() -> [WidgetTriggerSnapshot] {
        guard let data = WidgetSharing.defaults.data(forKey: WidgetSharing.snapshotsKey),
              let payload = try? JSONDecoder().decode(WidgetSnapshotPayload.self, from: data) else {
            return []
        }
        return payload.triggers
    }

    static var preferredTriggerId: String? {
        WidgetSharing.defaults.string(forKey: WidgetSharing.preferredTriggerKey)
    }

    static func snapshot(for id: String?) -> WidgetTriggerSnapshot? {
        let triggers = load()
        if let id, let match = triggers.first(where: { $0.id == id }) {
            return match
        }
        if let preferred = preferredTriggerId,
           let match = triggers.first(where: { $0.id == preferred }) {
            return match
        }
        return triggers.first
    }
}
