import SwiftUI

/// Apprch design-system color tokens (Primary / Secondary / Tertiary / Neutral).
/// Hex values match `design/apprch-tokens.json` and the Figma Collaborators Hub variables.
enum ApprchColor {
    enum Primary {
        static let c100 = Color(hex: 0xF2F7FF)
        static let c200 = Color(hex: 0xC0D7FF)
        static let c300 = Color(hex: 0x92B7F7)
        static let c400 = Color(hex: 0x6796EA)
        static let c500 = Color(hex: 0x3C74DC)
        static let c600 = Color(hex: 0x2A59B2)
        static let c700 = Color(hex: 0x183F8A)
        static let c800 = Color(hex: 0x072763)
        static let c900 = Color(hex: 0x00113E)
    }

    enum Secondary {
        static let c100 = Color(hex: 0xFFF5E9)
        static let c200 = Color(hex: 0xF9E0C1)
        static let c300 = Color(hex: 0xF1CB9C)
        static let c400 = Color(hex: 0xE8B677)
        static let c500 = Color(hex: 0xDEA14F)
        static let c600 = Color(hex: 0xB27737)
        static let c700 = Color(hex: 0x865021)
        static let c800 = Color(hex: 0x5B2D0B)
        static let c900 = Color(hex: 0x310E00)
    }

    enum Tertiary {
        static let c100 = Color(hex: 0xFBF9D7)
        static let c200 = Color(hex: 0xFBF3A4)
        static let c300 = Color(hex: 0xFCEC52)
        static let c400 = Color(hex: 0xDFC332)
        static let c500 = Color(hex: 0xC09C08)
        static let c600 = Color(hex: 0x9E7800)
        static let c700 = Color(hex: 0x7B5700)
        static let c800 = Color(hex: 0x583900)
        static let c900 = Color(hex: 0x351E00)
    }

    enum Neutral {
        static let c100 = Color(hex: 0xF6F8FA)
        static let c200 = Color(hex: 0xE7EBF3)
        static let c300 = Color(hex: 0xD6DBE3)
        static let c400 = Color(hex: 0xB9BEC6)
        static let c500 = Color(hex: 0x9498A0)
        static let c600 = Color(hex: 0x6B6F76)
        static let c700 = Color(hex: 0x4C5057)
        static let c800 = Color(hex: 0x32363C)
        static let c900 = Color(hex: 0x171B22)
    }

    static let black = Color(hex: 0x000000)
    static let white = Color(hex: 0xFFFFFF)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
