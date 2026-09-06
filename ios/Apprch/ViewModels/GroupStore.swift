import Foundation
import FirebaseAuth
import FirebaseFirestore

enum GroupStore {
    static func create(name: String, solo: Bool) async throws {
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

        let batch = db.batch()
        batch.setData(group, forDocument: groupRef)
        batch.setData(
            ["groupId": groupRef.documentID, "solo": solo],
            forDocument: db.collection("users").document(uid),
            merge: true
        )
        if let inviteCode {
            batch.setData(
                ["groupId": groupRef.documentID, "createdByUid": uid],
                forDocument: db.collection("inviteCodes").document(inviteCode)
            )
        }
        try await batch.commit()
    }

    static func join(inviteCode: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupStoreError.signedOut
        }

        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let db = Firestore.firestore()
        let inviteSnap = try await db.collection("inviteCodes").document(code).getDocument()
        guard let groupId = inviteSnap.data()?["groupId"] as? String else {
            throw GroupStoreError.invalidCode
        }

        let groupRef = db.collection("groups").document(groupId)
        let batch = db.batch()
        batch.updateData(
            ["memberUids": FieldValue.arrayUnion([uid])],
            forDocument: groupRef
        )
        batch.setData(
            ["groupId": groupId, "solo": false],
            forDocument: db.collection("users").document(uid),
            merge: true
        )
        try await batch.commit()
    }

    static func userFacingMessage(for error: Error) -> String {
        if let storeError = error as? GroupStoreError {
            return storeError.localizedDescription
        }
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("not found")
            || text.localizedCaseInsensitiveContains("permission") {
            return "Couldn’t finish setup. Check your connection and try again."
        }
        return text
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

    var errorDescription: String? {
        switch self {
        case .signedOut: return "Please sign in again."
        case .invalidCode: return "That invite code isn’t valid."
        case .soloSpace: return "This is a solo space and can’t be joined."
        }
    }
}
