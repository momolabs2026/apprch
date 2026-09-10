import Foundation
import FirebaseFirestore

struct TriggerEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var groupId: String
    var taskId: String
    var loggedByUid: String
    var timestamp: Timestamp?
    var metadata: [String: String]?

    var date: Date {
        timestamp?.dateValue() ?? Date()
    }
}
