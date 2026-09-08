import Foundation

enum AppLinks {
    static let tagHostCandidates = ["apprch.app", "www.apprch.app", "apprch.web.app"]

    static func triggerId(from url: URL) -> String? {
        if let id = queryTriggerId(from: url) { return id }

        let pathParts = url.pathComponents.filter { $0 != "/" }

        // https://apprch.web.app/t/{id}  and  apprch:///t/{id}
        if pathParts.count >= 2, pathParts[0] == "t", !pathParts[1].isEmpty {
            return pathParts[1]
        }

        // apprch://t/{id} — host is "t", path is /{id}
        if url.scheme?.lowercased() == "apprch",
           url.host?.lowercased() == "t",
           let id = pathParts.first, !id.isEmpty {
            return id
        }

        return nil
    }

    private static func queryTriggerId(from url: URL) -> String? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        guard let id = items?.first(where: { $0.name == "id" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else { return nil }
        return id
    }

    static func tagURL(triggerId: String) -> String {
        "apprch://open?id=\(triggerId)"
    }

    static func webURL(triggerId: String) -> String {
        "https://apprch.web.app/t/\(triggerId)"
    }
}
