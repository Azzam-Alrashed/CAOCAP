import Foundation
import Testing
@testable import caocap

struct TokenUsageLimiterTests {
    @Test func unsubscribedUserIsBlockedWhenPromptAndReserveExceedLimit() throws {
        let defaults = try makeDefaults()
        let limiter = TokenUsageLimiter(defaults: defaults, calendar: makeCalendar())
        let now = makeDate(year: 2026, month: 5, day: 24)

        limiter.record(prompt: String(repeating: "a", count: 24), response: "", isSubscribed: false, now: now)

        let result = limiter.preflight(
            prompt: String(repeating: "b", count: 12),
            isSubscribed: false,
            limitTokens: 10,
            responseReserveTokens: 2,
            now: now
        )

        guard case .failure(let error) = result else {
            Issue.record("Expected free-tier usage to be blocked.")
            return
        }

        #expect(error.limitTokens == 10)
        #expect(error.usedTokens == 6)
        #expect(error.requestedTokens == 5)
    }

    @Test func subscribedUserBypassesLimitAndDoesNotRecordUsage() throws {
        let defaults = try makeDefaults()
        let limiter = TokenUsageLimiter(defaults: defaults, calendar: makeCalendar())
        let now = makeDate(year: 2026, month: 5, day: 24)

        let result = limiter.preflight(
            prompt: String(repeating: "a", count: 400),
            isSubscribed: true,
            limitTokens: 10,
            responseReserveTokens: 10,
            now: now
        )
        limiter.record(prompt: String(repeating: "a", count: 400), response: "reply", isSubscribed: true, now: now)

        guard case .success = result else {
            Issue.record("Expected subscribed usage to bypass the free-tier limit.")
            return
        }

        #expect(limiter.status(limitTokens: 10, now: now).usedTokens == 0)
    }

    @Test func usageResetsWhenCalendarMonthChanges() throws {
        let defaults = try makeDefaults()
        let limiter = TokenUsageLimiter(defaults: defaults, calendar: makeCalendar())

        limiter.record(
            prompt: String(repeating: "a", count: 40),
            response: "",
            isSubscribed: false,
            now: makeDate(year: 2026, month: 5, day: 24)
        )

        let status = limiter.status(
            limitTokens: 10,
            now: makeDate(year: 2026, month: 6, day: 1)
        )

        #expect(status.periodKey == "2026-06")
        #expect(status.usedTokens == 0)
        #expect(status.remainingTokens == 10)
    }

    @Test func usageStatusFormatsTokensAndFlagsNearLimitAtEightyPercent() {
        let calm = TokenUsageStatus(periodKey: "2026-05", usedTokens: 15_900, limitTokens: 20_000)
        let near = TokenUsageStatus(periodKey: "2026-05", usedTokens: 16_000, limitTokens: 20_000)

        #expect(calm.formattedUsedTokens == "15.9k")
        #expect(near.formattedLimitTokens == "20k")
        #expect(!calm.isNearLimit)
        #expect(near.isNearLimit)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "TokenUsageLimiterTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestSetupError.failedToCreateDefaults
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(calendar: makeCalendar(), year: year, month: month, day: day).date!
    }

    private enum TestSetupError: Error {
        case failedToCreateDefaults
    }
}
