import Foundation

enum AppLinks {
    static let tagHostCandidates = ["apprch.app", "www.apprch.app", "apprch.web.app"]

    static func triggerId(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "t" else { return nil }
        let id = parts[1]
        return id.isEmpty ? nil : id
    }

    static func tagURL(triggerId: String) -> String {
        "https://apprch.web.app/t/\(triggerId)"
    }
}
