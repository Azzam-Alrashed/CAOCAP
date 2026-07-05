import Foundation
import Testing
@testable import caocap

struct AppIconServiceTests {
    @Test func exposesNineIconOptions() {
        #expect(AppIconService.options.count == 9)
        #expect(AppIconService.options.first?.id == "")
        #expect(AppIconService.options.first?.alternateIconName == nil)
        #expect(AppIconService.options[1].id == "AppIcon_8")
        #expect(AppIconService.options[1].displayName == "Classic Star")
        #expect(AppIconService.options.last?.id == "AppIcon_7")
        #expect(AppIconService.options.last?.alternateIconName == "AppIcon_7")
        #expect(AppIconService.options.last?.displayName == "Duo")
        #expect(!AppIconService.options.map(\.id).contains("AppIcon_4"))
    }

    @Test func includesCDLv2BrandIcons() {
        let ids = AppIconService.options.map(\.id)
        #expect(ids.contains("AppIcon_5"))
        #expect(ids.contains("AppIcon_6"))
        #expect(ids.contains("AppIcon_7"))

        let costar = AppIconService.options.first { $0.id == "AppIcon_5" }
        #expect(costar?.displayName == "CoStar")
        #expect(costar?.previewImageName == "AppIconPreview5")

        let cocaptain = AppIconService.options.first { $0.id == "AppIcon_6" }
        #expect(cocaptain?.displayName == "CoCaptain")
        #expect(cocaptain?.previewImageName == "AppIconPreview6")

        let costarClassic = AppIconService.options.first { $0.id == "AppIcon_8" }
        #expect(costarClassic?.displayName == "Classic Star")
        #expect(costarClassic?.previewImageName == "AppIconPreview8")
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
