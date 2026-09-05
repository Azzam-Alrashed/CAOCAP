import AppKit
import Foundation

/// Visual mood for the desktop companion. V1 only uses `idle`.
enum CompanionMood: String, Equatable {
    case idle
}

enum CompanionLayout {
    static let spriteSize: CGFloat = 112
    static let panelSize = NSSize(width: 144, height: 168)
    static let screenInset: CGFloat = 24
    static let clickSlop: CGFloat = 4
}

enum CompanionDefaults {
    static let isAwake = "companion.isAwake"
    static let originX = "companion.originX"
    static let originY = "companion.originY"
}
