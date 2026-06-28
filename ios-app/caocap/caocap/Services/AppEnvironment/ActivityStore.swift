import Foundation
import Observation

/// Receives successful project-save events without coupling persistence to the
/// concrete activity-history store.
@MainActor
public protocol ActivityRecording: AnyObject {
    func recordSuccessfulSave(at date: Date)
}

/// Default recorder for stores created outside the live app session, including tests.
@MainActor
public final class NoOpActivityRecorder: ActivityRecording {
    public init() {}
    public func recordSuccessfulSave(at date: Date = Date()) {}
}

/// One calendar cell in the activity heatmap.
public struct ActivityDay: Identifiable, Hashable {
    public let date: Date
    public let count: Int
    public let isFuture: Bool

    public var id: Date { date }

    /// GitHub-style five-step contribution intensity.
    public var intensity: Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2...3: return 2
        case 4...6: return 3
        default: return 4
        }
    }
}

/// Local-first, device-wide history of successful CAOCAP project saves.
@Observable
@MainActor
public final class ActivityStore: ActivityRecording {
    public static let shared = ActivityStore()

    private static let storageKey = "activity_daily_save_counts_v1"
    private static let retentionDays = 365

    private let defaults: UserDefaults
    private var calendar: Calendar
    private let now: () -> Date
    private var dailyCounts: [String: Int]

    public init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        self.calendar = sundayCalendar
        self.now = now
        self.dailyCounts = defaults.dictionary(forKey: Self.storageKey)?
            .compactMapValues { $0 as? Int } ?? [:]
        pruneHistory(referenceDate: now(), persist: false)
    }

    public func recordSuccessfulSave(at date: Date = Date()) {
        let key = dayKey(for: date)
        dailyCounts[key, default: 0] += 1
        pruneHistory(referenceDate: date, persist: false)
        defaults.set(dailyCounts, forKey: Self.storageKey)
    }

    /// Returns complete Sunday-to-Saturday weeks, ending with the week containing
    /// `endDate`. Dates after `endDate` are future placeholders.
    public func days(endingAt endDate: Date? = nil, weekCount: Int = 17) -> [ActivityDay] {
        guard weekCount > 0 else { return [] }

        let endDay = calendar.startOfDay(for: endDate ?? now())
        let weekday = calendar.component(.weekday, from: endDay)
        let daysSinceSunday = (weekday - calendar.firstWeekday + 7) % 7
        guard let currentWeekStart = calendar.date(
            byAdding: .day,
            value: -daysSinceSunday,
            to: endDay
        ),
        let firstDay = calendar.date(
            byAdding: .day,
            value: -(weekCount - 1) * 7,
            to: currentWeekStart
        ) else {
            return []
        }

        return (0..<(weekCount * 7)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            let isFuture = date > endDay
            return ActivityDay(
                date: date,
                count: isFuture ? 0 : dailyCounts[dayKey(for: date), default: 0],
                isFuture: isFuture
            )
        }
    }

    public var todayCount: Int {
        dailyCounts[dayKey(for: now()), default: 0]
    }

    public var activeDayCount: Int {
        days().filter { !$0.isFuture && $0.count > 0 }.count
    }

    public var totalSaveCount: Int {
        days().reduce(0) { $0 + $1.count }
    }

    public func reset() {
        dailyCounts = [:]
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func pruneHistory(referenceDate: Date, persist: Bool) {
        let referenceDay = calendar.startOfDay(for: referenceDate)
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -(Self.retentionDays - 1),
            to: referenceDay
        ) else {
            return
        }

        dailyCounts = dailyCounts.filter { key, _ in
            guard let date = date(forDayKey: key) else { return false }
            return date >= cutoff && date <= referenceDay
        }

        if persist {
            defaults.set(dailyCounts, forKey: Self.storageKey)
        }
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

    private func date(forDayKey key: String) -> Date? {
        let values = key.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }
        return calendar.date(from: DateComponents(
            year: values[0],
            month: values[1],
            day: values[2]
        ))
    }
}
