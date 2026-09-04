import Foundation
import FirebaseAuth
import FirebaseFirestore

actor FCMTokenManager {
    static let shared = FCMTokenManager()

    func upsertToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Firestore.firestore().collection("users").document(uid)
        try? await ref.setData(
            ["fcmTokens": FieldValue.arrayUnion([token])],
            merge: true
        )
    }
}
