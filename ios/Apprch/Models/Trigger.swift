import Foundation
import FirebaseFirestore

enum VisualizationType: String, Codable, CaseIterable, Identifiable {
    case log
    case counter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .log: return "Log"
        case .counter: return "Counter"
        }
    }

    var subtitle: String {
        switch self {
        case .log: return "A running history of each tap"
        case .counter: return "A history plus a running total"
        }
    }
}

struct Trigger: Identifiable, Codable {
    @DocumentID var id: String?
    var familyId: String
    var name: String
    var icon: String
    var notificationMessage: String
    var visualizationType: String
    var createdByUid: String
    var createdAt: Timestamp?
    var lastTriggeredAt: Timestamp?
    var lastTriggeredByUid: String?
    var eventCount: Int?

    var visualization: VisualizationType {
        VisualizationType(rawValue: visualizationType) ?? .log
    }

    var tagURLString: String {
        "https://apprch.web.app/t/\(id ?? "")"
    }
}
