import SwiftUI

extension Color {
    /// Creates a `Color` from a CSS-style hex string.
    ///
    /// Supported formats (leading `#` and whitespace are stripped automatically):
    /// - 3-digit RGB  (`"F0A"`) — each nibble is expanded to a byte by multiplying by 17.
    /// - 6-digit RGB  (`"FF00AA"`) — standard 24-bit color, full opacity.
    /// - 8-digit ARGB (`"CCFF00AA"`) — 32-bit with explicit alpha in the leading byte.
    ///
    /// Any unrecognised string produces a fully transparent near-white fallback.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            // Multiplying a 4-bit nibble by 17 maps [0x0...0xF] → [0x00...0xFF].
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
