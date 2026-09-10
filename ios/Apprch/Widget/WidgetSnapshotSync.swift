import Foundation
import FirebaseAuth
import FirebaseFirestore
import WidgetKit

enum WidgetSnapshotSync {
    static func refresh(groupIds: [String]) async {
        guard Auth.auth().currentUser != nil else {
            WidgetSnapshotStore.clear()
            return
        }
        let unique = Array(Set(groupIds.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return }

        var collected: [WidgetTriggerSnapshot] = []
        await withTaskGroup(of: [WidgetTriggerSnapshot].self) { group in
            for groupId in unique {
                group.addTask { await Self.loadSnapshots(in: groupId) }
            }
            for await batch in group {
                collected.append(contentsOf: batch)
            }
        }
        collected.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        WidgetSnapshotStore.save(collected)
    }

    static func refreshTrigger(id: String, groupId: String) async {
        guard Auth.auth().currentUser != nil else { return }
        let db = Firestore.firestore()
        guard let doc = try? await db.collection("tasks").document(id).getDocument(),
              let trigger = try? doc.data(as: Trigger.self),
              trigger.groupId == groupId,
              let snapshot = await loadSnapshot(for: trigger) else { return }
        WidgetSnapshotStore.upsert(snapshot)
    }

    private static func loadSnapshots(in groupId: String) async -> [WidgetTriggerSnapshot] {
        let db = Firestore.firestore()
        guard let snap = try? await db.collection("tasks")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments() else { return [] }
        let triggers = snap.documents.compactMap { try? $0.data(as: Trigger.self) }
        var result: [WidgetTriggerSnapshot] = []
        for trigger in triggers {
            if let snapshot = await loadSnapshot(for: trigger) {
                result.append(snapshot)
            }
        }
        return result
    }

    private static func loadSnapshot(for trigger: Trigger) async -> WidgetTriggerSnapshot? {
        guard let id = trigger.id else { return nil }
        let db = Firestore.firestore()
        let eventsSnap = try? await db.collection("events")
            .whereField("groupId", isEqualTo: trigger.groupId)
            .whereField("taskId", isEqualTo: id)
            .limit(to: 400)
            .getDocuments()
        let dates = eventsSnap?.documents.compactMap { doc -> Date? in
            (doc.data()["timestamp"] as? Timestamp)?.dateValue()
        } ?? []
        return WidgetTriggerSnapshot.make(
            id: id,
            name: trigger.name,
            icon: trigger.icon,
            accentColorHex: trigger.accentColorHex ?? TriggerAccent.fallbackHex,
            dates: dates
        )
    }
}

extension WidgetTriggerSnapshot {
    static func make(
        id: String,
        name: String,
        icon: String,
        accentColorHex: String,
        dates: [Date],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> WidgetTriggerSnapshot {
        let today = calendar.startOfDay(for: now)
        guard let yearAgo = calendar.date(byAdding: .day, value: -370, to: today) else {
            return WidgetTriggerSnapshot(
                id: id,
                name: name,
                icon: icon,
                accentColorHex: accentColorHex,
                countsByDay: [:],
                yearTotal: 0,
                todayCount: 0
            )
        }
        var counts: [String: Int] = [:]
        var yearTotal = 0
        var todayCount = 0
        for date in dates {
            let day = calendar.startOfDay(for: date)
            if day == today { todayCount += 1 }
            guard day >= yearAgo else { continue }
            let key = WidgetSharing.dayKeyFormatter.string(from: day)
            counts[key, default: 0] += 1
            yearTotal += 1
        }
        return WidgetTriggerSnapshot(
            id: id,
            name: name,
            icon: icon,
            accentColorHex: accentColorHex,
            countsByDay: counts,
            yearTotal: yearTotal,
            todayCount: todayCount
        )
    }
}
