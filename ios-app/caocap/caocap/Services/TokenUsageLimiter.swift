import Foundation

public struct TokenUsageStatus: Equatable {
    public let periodKey: String
    public let usedTokens: Int
    public let limitTokens: Int

    public var remainingTokens: Int {
        max(0, limitTokens - usedTokens)
    }
}

public struct TokenUsageLimitError: LocalizedError, Equatable {
    public let limitTokens: Int
    public let usedTokens: Int
    public let requestedTokens: Int

    public var errorDescription: String? {
        "You've reached this month's free CoCaptain usage. Upgrade to Pro to continue, or try again next month."
    }
}

/// Tracks local estimated LLM token usage for the free tier.
///
/// Firebase AI Logic does not currently flow exact usage accounting through
/// CAOCAP's app boundary, so this service uses a conservative character-based
/// estimate and resets usage by calendar month.
public final class TokenUsageLimiter {
    public static let shared = TokenUsageLimiter()

    public static let freeMonthlyTokenLimit = 20_000
    public static let minimumResponseTokenReserve = 1_000

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let periodKeyStorageKey = "cocaptain.tokenUsage.period"
    private let usedTokensStorageKey = "cocaptain.tokenUsage.usedTokens"

    public init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    public func status(
        limitTokens: Int = TokenUsageLimiter.freeMonthlyTokenLimit,
        now: Date = Date()
    ) -> TokenUsageStatus {
        resetIfNeeded(now: now)
        return TokenUsageStatus(
            periodKey: periodKey(for: now),
            usedTokens: defaults.integer(forKey: usedTokensStorageKey),
            limitTokens: limitTokens
        )
    }

    public func preflight(
        prompt: String,
        isSubscribed: Bool,
        limitTokens: Int = TokenUsageLimiter.freeMonthlyTokenLimit,
        responseReserveTokens: Int = TokenUsageLimiter.minimumResponseTokenReserve,
        now: Date = Date()
    ) -> Result<Void, TokenUsageLimitError> {
        guard !isSubscribed else { return .success(()) }

        let current = status(limitTokens: limitTokens, now: now)
        let requestedTokens = estimateTokens(in: prompt) + responseReserveTokens

        guard current.usedTokens + requestedTokens <= limitTokens else {
            return .failure(
                TokenUsageLimitError(
                    limitTokens: limitTokens,
                    usedTokens: current.usedTokens,
                    requestedTokens: requestedTokens
                )
            )
        }

        return .success(())
    }

    public func record(
        prompt: String,
        response: String,
        isSubscribed: Bool,
        now: Date = Date()
    ) {
        guard !isSubscribed else { return }

        resetIfNeeded(now: now)
        let usage = estimateTokens(in: prompt) + estimateTokens(in: response)
        let usedTokens = defaults.integer(forKey: usedTokensStorageKey)
        defaults.set(usedTokens + usage, forKey: usedTokensStorageKey)
    }

    public func reset(now: Date = Date()) {
        defaults.set(periodKey(for: now), forKey: periodKeyStorageKey)
        defaults.set(0, forKey: usedTokensStorageKey)
    }

    public func estimateTokens(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return max(1, Int(ceil(Double(trimmed.count) / 4.0)))
    }

    private func resetIfNeeded(now: Date) {
        let currentPeriod = periodKey(for: now)
        guard defaults.string(forKey: periodKeyStorageKey) != currentPeriod else { return }
        reset(now: now)
    }

    private func periodKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }
}
