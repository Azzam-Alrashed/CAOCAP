import Foundation
import Testing
@testable import caocap

@MainActor
struct ActivityStoreTests {
    @Test func recordsCountsAndMapsIntensityLevels() throws {
        let context = try makeContext(name: "intensity")
        defer { context.reset() }
        let store = context.store

        store.recordSuccessfulSave(at: context.now)
        #expect(store.todayCount == 1)
        #expect(store.days().first(where: { $0.date == context.now })?.intensity == 1)

        store.recordSuccessfulSave(at: context.now)
        #expect(store.days().first(where: { $0.date == context.now })?.intensity == 2)

        store.recordSuccessfulSave(at: context.now)
        store.recordSuccessfulSave(at: context.now)
        #expect(store.days().first(where: { $0.date == context.now })?.intensity == 3)

        for _ in 0..<3 { store.recordSuccessfulSave(at: context.now) }
        #expect(store.todayCount == 7)
        #expect(store.days().first(where: { $0.date == context.now })?.intensity == 4)
    }

    @Test func producesSeventeenSundayToSaturdayWeeksWithFuturePlaceholders() throws {
        let context = try makeContext(name: "weeks")
        defer { context.reset() }
        let days = context.store.days(weekCount: 17)

        #expect(days.count == 119)
        #expect(context.calendar.component(.weekday, from: days[0].date) == 1)
        #expect(context.calendar.component(.weekday, from: days[6].date) == 7)
        #expect(days.filter(\.isFuture).count == 3)
        #expect(days.last?.isFuture == true)
    }

    @Test func aggregatesActivityAcrossRecordersUsingTheSameDefaults() throws {
        let suiteName = "ActivityStoreTests.aggregate.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = testCalendar()
        let now = try date(2026, 6, 24, calendar: calendar)
        let first = ActivityStore(defaults: defaults, calendar: calendar, now: { now })
        first.recordSuccessfulSave(at: now)
        let second = ActivityStore(defaults: defaults, calendar: calendar, now: { now })
        second.recordSuccessfulSave(at: now)

        let reloaded = ActivityStore(defaults: defaults, calendar: calendar, now: { now })
        #expect(reloaded.todayCount == 2)
    }

    @Test func prunesActivityOlderThanOneYear() throws {
        let context = try makeContext(name: "retention")
        defer { context.reset() }
        let oldDate = try #require(context.calendar.date(
            byAdding: .day,
            value: -365,
            to: context.now
        ))

        context.store.recordSuccessfulSave(at: oldDate)
        context.store.recordSuccessfulSave(at: context.now)

        let oldDay = context.store.days(endingAt: oldDate).first { $0.date == oldDate }
        #expect(oldDay?.count == 0)
        #expect(context.store.todayCount == 1)
    }

    @Test func resetClearsPersistedAndInMemoryActivity() throws {
        let context = try makeContext(name: "reset")
        defer { context.reset() }
        context.store.recordSuccessfulSave(at: context.now)

        context.store.reset()

        #expect(context.store.todayCount == 0)
        let reloaded = ActivityStore(
            defaults: context.defaults,
            calendar: context.calendar,
            now: { context.now }
        )
        #expect(reloaded.todayCount == 0)
    }

    private func makeContext(name: String) throws -> TestContext {
        let suiteName = "ActivityStoreTests.\(name).\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let calendar = testCalendar()
        let now = try date(2026, 6, 24, calendar: calendar)
        return TestContext(
            suiteName: suiteName,
            defaults: defaults,
            calendar: calendar,
            now: now,
            store: ActivityStore(defaults: defaults, calendar: calendar, now: { now })
        )
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private struct TestContext {
        let suiteName: String
        let defaults: UserDefaults
        let calendar: Calendar
        let now: Date
        let store: ActivityStore

        func reset() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}
