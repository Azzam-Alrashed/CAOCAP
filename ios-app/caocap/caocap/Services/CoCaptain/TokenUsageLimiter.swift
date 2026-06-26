import Foundation

/// A snapshot of token consumption for the current billing period.
public struct TokenUsageStatus: Equatable {
    /// A `"YYYY-MM"` key identifying the calendar month this status covers.
    public let periodKey: String
    /// Estimated tokens consumed so far this month.
    public let usedTokens: Int
    /// The maximum tokens allowed this month for the current tier.
    public let limitTokens: Int

    /// How many more tokens the user can spend before hitting the monthly cap.
    public var remainingTokens: Int {
        max(0, limitTokens - usedTokens)
    }
}

/// Thrown by `TokenUsageLimiter.preflight` when the incoming request
/// would push usage past the monthly free-tier cap.
public struct TokenUsageLimitError: LocalizedError, Equatable {
    /// The configured monthly token ceiling.
    public let limitTokens: Int
    /// Tokens already consumed this period before this request.
    public let usedTokens: Int
    /// Estimated cost of the incoming prompt plus the response reserve.
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

    /// Returns the current usage snapshot, resetting the counter automatically
    /// when the calendar month has rolled over.
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

    /// Guards a pending LLM call against the monthly cap before the request is sent.
    ///
    /// Subscribers bypass the check entirely. For free-tier users the prompt's estimated
    /// token cost plus `responseReserveTokens` is added to current usage; if the sum
    /// exceeds the limit, a `TokenUsageLimitError` is returned so the caller can surface
    /// an upgrade prompt instead of sending the request.
    ///
    /// - Parameters:
    ///   - prompt: The full prompt string that will be sent to the model.
    ///   - isSubscribed: Skip enforcement when the user holds an active Pro subscription.
    ///   - limitTokens: Monthly cap; defaults to `freeMonthlyTokenLimit`.
    ///   - responseReserveTokens: Extra tokens reserved for the expected model reply.
    ///   - now: Injection point for the current date (useful in tests).
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

    /// Records token usage after a completed LLM exchange.
    ///
    /// Call this once the full model response has been streamed so both
    /// the prompt and the actual response length are known. Subscribers
    /// are exempt from tracking.
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

    /// Resets the usage counter for the given date's period and writes the new period key.
    /// Normally called automatically by `resetIfNeeded`; exposed publicly for testing.
    public func reset(now: Date = Date()) {
        defaults.set(periodKey(for: now), forKey: periodKeyStorageKey)
        defaults.set(0, forKey: usedTokensStorageKey)
    }

    /// Estimates the token count of `text` using a 4-characters-per-token heuristic.
    ///
    /// Firebase AI Logic doesn't expose exact usage through the CAOCAP app boundary,
    /// so a conservative approximation is used to stay within the free-tier envelope.
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
