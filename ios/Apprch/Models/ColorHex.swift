import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            r = 0.18; g = 0.8; b = 0.44
        }
        self.init(red: r, green: g, blue: b)
    }

    func hexString() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    func heatmapFill(level: Int) -> Color {
        switch max(0, min(level, 4)) {
        case 0: return Color.secondary.opacity(0.16)
        case 1: return opacity(0.28)
        case 2: return opacity(0.5)
        case 3: return opacity(0.74)
        default: return opacity(1)
        }
    }
}

extension Date {
    var apprchRelativeString: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 {
            let minutes = max(1, Int(seconds / 60))
            return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
        }
        if seconds < 86_400 {
            let hours = max(1, Int(seconds / 3600))
            return hours == 1 ? "1 hr ago" : "\(hours) hr ago"
        }
        return formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}

enum TriggerAccent {
    static let fallbackHex = "#2ECC71"
    static let presets = [
        "#2ECC71", "#3498DB", "#9B59B6", "#E74C3C",
        "#E67E22", "#F1C40F", "#1ABC9C", "#E91E63"
    ]
}
