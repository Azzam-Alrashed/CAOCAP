import Foundation
import Testing
@testable import caocap

struct AppIconServiceTests {
    @Test func exposesSevenIconOptions() {
        #expect(AppIconService.options.count == 7)
        #expect(AppIconService.options.first?.id == "")
        #expect(AppIconService.options.first?.alternateIconName == nil)
        #expect(AppIconService.options.last?.id == "AppIcon_5")
        #expect(AppIconService.options.last?.alternateIconName == "AppIcon_5")
        #expect(AppIconService.options.last?.displayName == "CoStar")
    }

    @Test func persistsSelectionInUserDefaults() throws {
        let suiteName = "AppIconServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("AppIcon_2", forKey: AppIconService.storageKey)
        #expect(defaults.string(forKey: AppIconService.storageKey) == "AppIcon_2")

        defaults.set("", forKey: AppIconService.storageKey)
        #expect(defaults.string(forKey: AppIconService.storageKey) == "")
    }
}
