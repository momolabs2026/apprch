import Foundation
import WidgetKit

enum WidgetSharing {
    static let appGroupID = "group.com.momo-labs.Apprch"
    static let snapshotsKey = "widget.snapshots"
    static let preferredTriggerKey = "widget.preferredTriggerId"
    static let pendingPinKey = "widget.pendingPinTriggerId"
    static let pendingPinAtKey = "widget.pendingPinAt"

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

    static func save(_ triggers: [WidgetTriggerSnapshot]) {
        let payload = WidgetSnapshotPayload(triggers: triggers)
        WidgetSharing.defaults.set(
            try? JSONEncoder().encode(payload),
            forKey: WidgetSharing.snapshotsKey
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func upsert(_ snapshot: WidgetTriggerSnapshot) {
        var triggers = load()
        if let index = triggers.firstIndex(where: { $0.id == snapshot.id }) {
            triggers[index] = snapshot
        } else {
            triggers.append(snapshot)
        }
        save(triggers)
    }

    static func remove(ids: Set<String>) {
        let remaining = load().filter { !ids.contains($0.id) }
        save(remaining)
    }

    static func clear() {
        WidgetSharing.defaults.removeObject(forKey: WidgetSharing.snapshotsKey)
        WidgetSharing.defaults.removeObject(forKey: WidgetSharing.preferredTriggerKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var preferredTriggerId: String? {
        get { WidgetSharing.defaults.string(forKey: WidgetSharing.preferredTriggerKey) }
        set { WidgetSharing.defaults.set(newValue, forKey: WidgetSharing.preferredTriggerKey) }
    }

    static func markPendingPin(triggerId: String) {
        preferredTriggerId = triggerId
        WidgetSharing.defaults.set(triggerId, forKey: WidgetSharing.pendingPinKey)
        WidgetSharing.defaults.set(Date().timeIntervalSince1970, forKey: WidgetSharing.pendingPinAtKey)
    }
}
