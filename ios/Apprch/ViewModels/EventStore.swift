import Foundation
import FirebaseAuth
import FirebaseFirestore

enum EventStore {
    static func log(triggerId: String, groupId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw EventStoreError.signedOut
        }

        let db = Firestore.firestore()
        let taskRef = db.collection("tasks").document(triggerId)
        let snapshot = try await taskRef.getDocument()
        guard snapshot.exists, snapshot.data()?["groupId"] as? String == groupId else {
            throw EventStoreError.unavailable
        }

        let eventRef = db.collection("events").document()
        let batch = db.batch()
        batch.setData(
            [
                "groupId": groupId,
                "taskId": triggerId,
                "loggedByUid": uid,
                "timestamp": FieldValue.serverTimestamp()
            ],
            forDocument: eventRef
        )
        batch.updateData(
            [
                "lastLoggedAt": FieldValue.serverTimestamp(),
                "lastLoggedByUid": uid,
                "eventCount": FieldValue.increment(Int64(1))
            ],
            forDocument: taskRef
        )
        try await batch.commit()
        await WidgetSnapshotSync.refreshTrigger(id: triggerId, groupId: groupId)
    }

    static func toggleToday(triggerId: String, groupId: String, currentlyComplete: Bool) async throws {
        if currentlyComplete {
            try await undoToday(triggerId: triggerId, groupId: groupId)
        } else {
            try await log(triggerId: triggerId, groupId: groupId)
        }
    }

    static func undoToday(triggerId: String, groupId: String) async throws {
        guard Auth.auth().currentUser?.uid != nil else {
            throw EventStoreError.signedOut
        }

        let db = Firestore.firestore()
        let taskRef = db.collection("tasks").document(triggerId)
        let snapshot = try await taskRef.getDocument()
        guard snapshot.exists, snapshot.data()?["groupId"] as? String == groupId else {
            throw EventStoreError.unavailable
        }

        let eventsSnap = try await db.collection("events")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("taskId", isEqualTo: triggerId)
            .getDocuments()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        var today: [QueryDocumentSnapshot] = []
        var earlier: [QueryDocumentSnapshot] = []
        for doc in eventsSnap.documents {
            guard let timestamp = doc.data()["timestamp"] as? Timestamp else {
                today.append(doc)
                continue
            }
            if timestamp.dateValue() >= startOfDay {
                today.append(doc)
            } else {
                earlier.append(doc)
            }
        }

        let latestEarlier = earlier.max { lhs, rhs in
            let l = (lhs.data()["timestamp"] as? Timestamp)?.dateValue() ?? .distantPast
            let r = (rhs.data()["timestamp"] as? Timestamp)?.dateValue() ?? .distantPast
            return l < r
        }

        let batch = db.batch()
        for doc in today {
            batch.deleteDocument(doc.reference)
        }

        let currentCount = (snapshot.data()?["eventCount"] as? Int)
            ?? (snapshot.data()?["eventCount"] as? Int64).map(Int.init)
            ?? eventsSnap.documents.count
        var taskUpdate: [String: Any] = [
            "eventCount": max(0, currentCount - today.count)
        ]
        if let latestEarlier {
            taskUpdate["lastLoggedAt"] = latestEarlier.data()["timestamp"] as Any
            taskUpdate["lastLoggedByUid"] = (latestEarlier.data()["loggedByUid"] ?? latestEarlier.data()["triggeredByUid"]) as Any
        } else {
            taskUpdate["lastLoggedAt"] = FieldValue.delete()
            taskUpdate["lastLoggedByUid"] = FieldValue.delete()
        }
        batch.updateData(taskUpdate, forDocument: taskRef)
        try await batch.commit()
        await WidgetSnapshotSync.refreshTrigger(id: triggerId, groupId: groupId)
    }

    static func userFacingMessage(for error: Error) -> String {
        if let storeError = error as? EventStoreError {
            return storeError.localizedDescription
        }
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("permission")
            || text.localizedCaseInsensitiveContains("unauthenticated") {
            return "Couldn’t log this. Check that you’re signed in and try again."
        }
        return text
    }
}

enum EventStoreError: LocalizedError {
    case signedOut
    case unavailable

    var errorDescription: String? {
        switch self {
        case .signedOut: return "Please sign in again."
        case .unavailable: return "This task isn’t available."
        }
    }
}
