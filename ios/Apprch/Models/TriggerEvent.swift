import Foundation
import FirebaseFirestore

struct TriggerEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var familyId: String
    var triggerId: String
    var triggeredByUid: String
    var timestamp: Timestamp?
    var metadata: [String: String]?

    var date: Date {
        timestamp?.dateValue() ?? Date()
    }
}
