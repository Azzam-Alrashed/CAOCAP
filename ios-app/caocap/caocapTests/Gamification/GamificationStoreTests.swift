import Foundation
import Testing
@testable import caocap

struct GamificationStoreTests {
  @Test func completingChallengeAwardsXPOncePerDay() throws {
    let suiteName = "GamificationStoreTests.challenge.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = GamificationStore(defaults: defaults)
    var html = ProjectTemplateProvider.defaultCode
    html = html.replacingOccurrences(of: "<title>My App</title>", with: "<title>Studio</title>")

    let first = store.evaluateMiniApps(htmlSamples: [html])
    #expect(first.count == 1)
    #expect(store.totalXP == 10)

    let second = store.evaluateMiniApps(htmlSamples: [html])
    #expect(second.isEmpty)
    #expect(store.totalXP == 10)
  }

  @Test func saveXPIsCappedPerDay() throws {
    let suiteName = "GamificationStoreTests.save.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = GamificationStore(defaults: defaults)
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    store.recordSuccessfulSave(at: now)
    store.recordSuccessfulSave(at: now)
    store.recordSuccessfulSave(at: now)
    store.recordSuccessfulSave(at: now)

    #expect(store.totalXP == 15)
  }

  @Test func levelProgressUsesXPThresholds() {
    let progress = XPLevelTable.progress(for: 160)
    #expect(progress.level == 3)
    #expect(progress.title == "Builder")
  }
}
