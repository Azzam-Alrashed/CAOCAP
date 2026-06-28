import Foundation

public struct XPLevelProgress: Equatable, Sendable {
    public let level: Int
    public let title: String
    public let currentXP: Int
    public let xpForCurrentLevel: Int
    public let xpForNextLevel: Int

    public var xpIntoLevel: Int {
        max(0, currentXP - xpForCurrentLevel)
    }

    public var xpNeededForNextLevel: Int {
        max(1, xpForNextLevel - xpForCurrentLevel)
    }

    public var progressFraction: Double {
        Double(xpIntoLevel) / Double(xpNeededForNextLevel)
    }
}

public enum XPLevelTable {
    private static let titles = [
        "Visitor",
        "Tinkerer",
        "Builder",
        "Maker",
        "Architect"
    ]

    private static let thresholds = [0, 50, 150, 350, 700]

    public static func progress(for totalXP: Int) -> XPLevelProgress {
        let boundedXP = max(0, totalXP)
        let levelIndex = thresholds.lastIndex(where: { boundedXP >= $0 }) ?? 0
        let nextIndex = min(levelIndex + 1, thresholds.count - 1)
        return XPLevelProgress(
            level: levelIndex + 1,
            title: titles[min(levelIndex, titles.count - 1)],
            currentXP: boundedXP,
            xpForCurrentLevel: thresholds[levelIndex],
            xpForNextLevel: thresholds[nextIndex]
        )
    }
}
