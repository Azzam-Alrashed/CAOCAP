import Foundation
import Observation

@Observable
@MainActor
public final class GamificationStore {
    public static let shared = GamificationStore()

    private static let xpStorageKey = "gamification_xp_v1"
    private static let dailyCompletionsKey = "gamification_daily_completions_v1"
    private static let saveXPCountKey = "gamification_save_xp_counts_v1"
    private static let saveXPPerDay = 5
    private static let maxSaveXPAwardsPerDay = 3

    private let defaults: UserDefaults
    private var calendar: Calendar
    private let now: () -> Date

    public private(set) var totalXP: Int
    private var dailyCompletionsByDay: [String: [String]]
    private var saveXPAwardsByDay: [String: Int]

    public var challengesForToday: [DailyChallengeDefinition] {
        refreshDayIfNeeded()
        return DailyChallengeDefinition.catalog
    }

    public var completedChallengeIDsToday: Set<String> {
        refreshDayIfNeeded()
        return Set(dailyCompletionsByDay[currentDayKey(), default: []])
    }

    public var levelProgress: XPLevelProgress {
        XPLevelTable.progress(for: totalXP)
    }

    public var completedCountToday: Int {
        completedChallengeIDsToday.count
    }

    public init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.totalXP = defaults.integer(forKey: Self.xpStorageKey)
        self.dailyCompletionsByDay = defaults.dictionary(forKey: Self.dailyCompletionsKey) as? [String: [String]] ?? [:]
        self.saveXPAwardsByDay = defaults.dictionary(forKey: Self.saveXPCountKey) as? [String: Int] ?? [:]
    }

    @discardableResult
    public func evaluateMiniApps(htmlSamples: [String]) -> [DailyChallengeDefinition] {
        refreshDayIfNeeded()
        let combinedHTML = htmlSamples.joined(separator: "\n")
        guard !combinedHTML.isEmpty else { return [] }

        let matched = DailyChallengeDetector.matchedChallengeIDs(in: combinedHTML)
        let dayKey = currentDayKey()
        var completedToday = Set(dailyCompletionsByDay[dayKey, default: []])
        var newlyCompleted: [DailyChallengeDefinition] = []

        for challenge in DailyChallengeDefinition.catalog where matched.contains(challenge.id) {
            guard !completedToday.contains(challenge.id) else { continue }
            completedToday.insert(challenge.id)
            awardXP(challenge.tier.xpReward)
            newlyCompleted.append(challenge)
        }

        if !newlyCompleted.isEmpty {
            dailyCompletionsByDay[dayKey] = Array(completedToday)
            persist()
        }

        return newlyCompleted
    }

    public func recordSuccessfulSave(at date: Date = Date()) {
        let dayKey = dayKey(for: date)
        let awards = saveXPAwardsByDay[dayKey, default: 0]
        guard awards < Self.maxSaveXPAwardsPerDay else { return }
        saveXPAwardsByDay[dayKey] = awards + 1
        awardXP(Self.saveXPPerDay)
        persistSaveXP()
    }

    public func isChallengeCompletedToday(_ challengeID: String) -> Bool {
        completedChallengeIDsToday.contains(challengeID)
    }

    public func reset() {
        totalXP = 0
        dailyCompletionsByDay = [:]
        saveXPAwardsByDay = [:]
        defaults.removeObject(forKey: Self.xpStorageKey)
        defaults.removeObject(forKey: Self.dailyCompletionsKey)
        defaults.removeObject(forKey: Self.saveXPCountKey)
    }

    private func awardXP(_ amount: Int) {
        guard amount > 0 else { return }
        totalXP += amount
    }

    private func refreshDayIfNeeded() {
        _ = currentDayKey()
    }

    private func currentDayKey() -> String {
        dayKey(for: now())
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func persist() {
        defaults.set(totalXP, forKey: Self.xpStorageKey)
        defaults.set(dailyCompletionsByDay, forKey: Self.dailyCompletionsKey)
    }

    private func persistSaveXP() {
        defaults.set(totalXP, forKey: Self.xpStorageKey)
        defaults.set(saveXPAwardsByDay, forKey: Self.saveXPCountKey)
    }
}
