import Foundation
import FirebaseAuth
import FirebaseFirestore

enum GroupStore {
    static func create(name: String, solo: Bool) async throws {
        if !solo {
            _ = try await ensurePersonal()
        }
        _ = try await createSpace(name: name, solo: solo, makeActive: true)
    }

    @discardableResult
    static func ensurePersonal() async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupStoreError.signedOut
        }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        let userSnap = try await userRef.getDocument()
        let data = userSnap.data() ?? [:]

        if let personalId = data["personalGroupId"] as? String, !personalId.isEmpty {
            return personalId
        }

        if let groupId = data["groupId"] as? String,
           let group = try await db.collection("groups").document(groupId).getDocument().data(),
           group["solo"] as? Bool == true {
            try await userRef.setData(
                [
                    "personalGroupId": groupId,
                    "groupIds": FieldValue.arrayUnion([groupId]),
                    "activeGroupId": data["activeGroupId"] as? String ?? groupId,
                    "groupId": data["groupId"] as? String ?? groupId,
                    "solo": data["solo"] as? Bool ?? true
                ],
                merge: true
            )
            return groupId
        }

        return try await createSpace(name: "Solo", solo: true, makeActive: data["groupId"] == nil)
    }

    static func migrateLegacyUserIfNeeded() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = Firestore.firestore().collection("users").document(uid)
        let data = try await userRef.getDocument().data() ?? [:]
        if let ids = data["groupIds"] as? [Any], !ids.isEmpty { return }
        guard let groupId = data["groupId"] as? String else { return }

        let solo = data["solo"] as? Bool ?? false
        if solo {
            try await userRef.setData(
                [
                    "personalGroupId": groupId,
                    "groupIds": [groupId],
                    "activeGroupId": groupId
                ],
                merge: true
            )
            return
        }

        let personalId = try await ensurePersonal()
        try await userRef.setData(
            [
                "groupIds": FieldValue.arrayUnion([groupId, personalId]),
                "activeGroupId": groupId,
                "groupId": groupId,
                "solo": false
            ],
            merge: true
        )
    }

    static func join(inviteCode: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupStoreError.signedOut
        }

        _ = try await ensurePersonal()

        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let db = Firestore.firestore()
        let inviteSnap = try await db.collection("inviteCodes").document(code).getDocument()
        guard let groupId = inviteSnap.data()?["groupId"] as? String else {
            throw GroupStoreError.invalidCode
        }

        let batch = db.batch()
        batch.updateData(
            ["memberUids": FieldValue.arrayUnion([uid])],
            forDocument: db.collection("groups").document(groupId)
        )
        batch.setData(
            [
                "groupIds": FieldValue.arrayUnion([groupId]),
                "groupId": groupId,
                "activeGroupId": groupId,
                "solo": false
            ],
            forDocument: db.collection("users").document(uid),
            merge: true
        )
        try await batch.commit()
    }

    static func setActiveSpace(_ groupId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupStoreError.signedOut
        }
        let snapshot = try await Firestore.firestore().collection("groups").document(groupId).getDocument()
        guard snapshot.exists else { throw GroupStoreError.unavailable }
        let solo = snapshot.data()?["solo"] as? Bool ?? false
        try await Firestore.firestore().collection("users").document(uid).setData(
            [
                "groupId": groupId,
                "activeGroupId": groupId,
                "solo": solo
            ],
            merge: true
        )
    }

    static func directoryFields(displayName: String, email: String?) -> [String: Any] {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchName = name.lowercased()
        var tokens = Set(searchName.split(whereSeparator: \.isWhitespace).map(String.init))
        if !searchName.isEmpty { tokens.insert(searchName) }
        var fields: [String: Any] = [
            "displayName": name,
            "searchName": searchName,
            "nameTokens": Array(tokens)
        ]
        if let email, !email.isEmpty {
            fields["email"] = email.lowercased()
        }
        return fields
    }

    static func searchUsers(query: String, excluding excludedIds: Set<String>) async throws -> [SpaceMember] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.count >= 2 else { return [] }

        let db = Firestore.firestore()
        let token = needle.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? needle
        async let prefixDocs = db.collection("users")
            .whereField("searchName", isGreaterThanOrEqualTo: needle)
            .whereField("searchName", isLessThan: needle + "\u{f8ff}")
            .limit(to: 12)
            .getDocuments()
        async let tokenDocs = db.collection("users")
            .whereField("nameTokens", arrayContains: token)
            .limit(to: 12)
            .getDocuments()

        var snapshots = [try await prefixDocs, try await tokenDocs]
        if needle.contains("@") {
            snapshots.append(
                try await db.collection("users")
                    .whereField("email", isEqualTo: needle)
                    .limit(to: 5)
                    .getDocuments()
            )
        }

        var seen = Set<String>()
        var matches: [SpaceMember] = []
        for snapshot in snapshots {
            for doc in snapshot.documents {
                guard !excludedIds.contains(doc.documentID), seen.insert(doc.documentID).inserted else { continue }
                let data = doc.data()
                let name = (data["displayName"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Someone"
                matches.append(
                    SpaceMember(
                        id: doc.documentID,
                        name: name,
                        photoBase64: data["photoBase64"] as? String,
                        email: data["email"] as? String
                    )
                )
            }
        }
        return matches.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func addMember(_ uid: String, toGroupId groupId: String) async throws {
        guard let me = Auth.auth().currentUser?.uid else {
            throw GroupStoreError.signedOut
        }
        guard uid != me else { throw GroupStoreError.alreadyMember }

        let groupRef = Firestore.firestore().collection("groups").document(groupId)
        let snapshot = try await groupRef.getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            throw GroupStoreError.unavailable
        }
        if data["solo"] as? Bool == true {
            throw GroupStoreError.soloSpace
        }
        let members = data["memberUids"] as? [String] ?? []
        guard members.contains(me) else {
            throw GroupStoreError.unavailable
        }
        if members.contains(uid) {
            throw GroupStoreError.alreadyMember
        }
        try await groupRef.updateData(["memberUids": FieldValue.arrayUnion([uid])])
    }

    static func members(in groupId: String) async throws -> [SpaceMember] {
        let snapshot = try await Firestore.firestore().collection("groups").document(groupId).getDocument()
        let uids = snapshot.data()?["memberUids"] as? [String] ?? []
        var members: [SpaceMember] = []
        for uid in uids {
            let user = try await Firestore.firestore().collection("users").document(uid).getDocument()
            let data = user.data() ?? [:]
            members.append(
                SpaceMember(
                    id: uid,
                    name: (data["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Someone",
                    photoBase64: data["photoBase64"] as? String
                )
            )
        }
        return members.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func spaces() async throws -> [Space] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupStoreError.signedOut
        }
        let snapshot = try await Firestore.firestore()
            .collection("groups")
            .whereField("memberUids", arrayContains: uid)
            .getDocuments()
        return snapshot.documents.compactMap { doc -> Space? in
            let data = doc.data()
            guard let name = data["name"] as? String else { return nil }
            return Space(id: doc.documentID, name: name, solo: data["solo"] as? Bool ?? false)
        }
        .sorted { lhs, rhs in
            if lhs.solo != rhs.solo { return lhs.solo && !rhs.solo }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func inviteCode(for groupId: String) async throws -> (code: String?, solo: Bool, name: String) {
        let snapshot = try await Firestore.firestore()
            .collection("groups")
            .document(groupId)
            .getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            throw GroupStoreError.unavailable
        }
        let code = data["inviteCode"] as? String
        let trimmed = code?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            (trimmed?.isEmpty == false) ? trimmed : nil,
            data["solo"] as? Bool ?? false,
            data["name"] as? String ?? ""
        )
    }

    @discardableResult
    static func enableInvites(groupId: String, name: String? = nil) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupStoreError.signedOut
        }

        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupId)
        let snapshot = try await groupRef.getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            throw GroupStoreError.unavailable
        }
        let members = data["memberUids"] as? [String] ?? []
        guard members.contains(uid) else {
            throw GroupStoreError.unavailable
        }
        if data["solo"] as? Bool == true {
            throw GroupStoreError.soloSpace
        }

        let existing = (data["inviteCode"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing, !existing.isEmpty {
            return existing
        }

        let code = randomInviteCode()
        let batch = db.batch()
        batch.updateData(["inviteCode": code], forDocument: groupRef)
        batch.setData(
            ["groupId": groupId, "createdByUid": uid],
            forDocument: db.collection("inviteCodes").document(code)
        )
        try await batch.commit()
        return code
    }

    static func moveTrigger(_ triggerId: String, toGroupId: String) async throws {
        guard Auth.auth().currentUser?.uid != nil else {
            throw GroupStoreError.signedOut
        }
        let db = Firestore.firestore()
        let taskRef = db.collection("tasks").document(triggerId)
        let taskSnap = try await taskRef.getDocument()
        guard taskSnap.exists else { throw GroupStoreError.unavailable }
        guard let fromGroupId = taskSnap.data()?["groupId"] as? String else {
            throw GroupStoreError.unavailable
        }
        guard fromGroupId != toGroupId else { return }

        try await taskRef.updateData(["groupId": toGroupId])

        let events = try await db.collection("events")
            .whereField("groupId", isEqualTo: fromGroupId)
            .whereField("taskId", isEqualTo: triggerId)
            .getDocuments()
        guard !events.documents.isEmpty else { return }

        let batch = db.batch()
        for doc in events.documents {
            batch.updateData(["groupId": toGroupId], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    @discardableResult
    static func createGroup(named name: String, movingTriggerId triggerId: String?) async throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GroupStoreError.needsName }
        _ = try await ensurePersonal()
        let groupId = try await createSpace(name: trimmed, solo: false, makeActive: true)
        if let triggerId {
            try await moveTrigger(triggerId, toGroupId: groupId)
        }
        return groupId
    }

    static func userFacingMessage(for error: Error) -> String {
        if let storeError = error as? GroupStoreError {
            return storeError.localizedDescription
        }
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("not found")
            || text.localizedCaseInsensitiveContains("permission") {
            return "Couldn’t finish that. Check your connection and try again."
        }
        return text
    }

    @discardableResult
    private static func createSpace(name: String, solo: Bool, makeActive: Bool) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupStoreError.signedOut
        }

        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document()
        let inviteCode = solo ? nil : randomInviteCode()
        var group: [String: Any] = [
            "name": name,
            "solo": solo,
            "memberUids": [uid],
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let inviteCode {
            group["inviteCode"] = inviteCode
        }

        var userUpdate: [String: Any] = [
            "groupIds": FieldValue.arrayUnion([groupRef.documentID])
        ]
        if solo {
            userUpdate["personalGroupId"] = groupRef.documentID
        }
        if makeActive {
            userUpdate["groupId"] = groupRef.documentID
            userUpdate["activeGroupId"] = groupRef.documentID
            userUpdate["solo"] = solo
        }

        let batch = db.batch()
        batch.setData(group, forDocument: groupRef)
        batch.setData(userUpdate, forDocument: db.collection("users").document(uid), merge: true)
        if let inviteCode {
            batch.setData(
                ["groupId": groupRef.documentID, "createdByUid": uid],
                forDocument: db.collection("inviteCodes").document(inviteCode)
            )
        }
        try await batch.commit()
        return groupRef.documentID
    }

    private static func randomInviteCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}

enum GroupStoreError: LocalizedError {
    case signedOut
    case invalidCode
    case soloSpace
    case unavailable
    case needsName
    case alreadyMember

    var errorDescription: String? {
        switch self {
        case .signedOut: return "Please sign in again."
        case .invalidCode: return "That invite code isn’t valid."
        case .soloSpace: return "Invite from a group, or move a Task into a new group."
        case .unavailable: return "Couldn’t load this space."
        case .needsName: return "Give the group a name first."
        case .alreadyMember: return "They’re already in this group."
        }
    }
}
