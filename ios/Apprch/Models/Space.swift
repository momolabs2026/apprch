import Foundation
import UIKit

struct Space: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let solo: Bool

    var title: String { solo ? "Solo" : name }
}

struct SpaceMember: Identifiable, Equatable {
    let id: String
    let name: String
    let photoBase64: String?
    var email: String? = nil

    var photo: UIImage? {
        Self.image(from: photoBase64)
    }

    var initial: String {
        String(name.prefix(1)).uppercased()
    }

    static func image(from base64: String?) -> UIImage? {
        guard let base64, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self, !value.isEmpty else { return nil }
        return value
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
