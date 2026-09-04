import Foundation
import FirebaseFirestore

struct FamilyEvent: Identifiable {
    let id: String
    let familyId: String
    let type: String
    let triggeredByUid: String
    let timestamp: Date

    var displayName: String {
        switch type {
        case "litter_cleaned": return "Litter box cleaned"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    init?(id: String, data: [String: Any]) {
        guard
            let familyId = data["familyId"] as? String,
            let type = data["type"] as? String,
            let triggeredByUid = data["triggeredByUid"] as? String,
            let ts = data["timestamp"] as? Timestamp
        else { return nil }

        self.id = id
        self.familyId = familyId
        self.type = type
        self.triggeredByUid = triggeredByUid
        self.timestamp = ts.dateValue()
    }
}
