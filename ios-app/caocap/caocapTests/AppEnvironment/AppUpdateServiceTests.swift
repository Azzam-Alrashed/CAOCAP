import Foundation
import Testing
@testable import caocap

struct AppUpdateServiceTests {
    @MainActor
    @Test func updateDecisionShowsWhenCurrentVersionIsBelowMinimum() async {
        let service = AppUpdateService(
            minimumVersionProvider: StubMinimumVersionProvider(result: .success("7.3.0")),
            appVersionProvider: StubAppVersionProvider(version: "7.2.0")
        )

        await service.checkForUpdate()

        #expect(service.availableUpdate?.currentVersion == "7.2.0")
        #expect(service.availableUpdate?.minimumRequiredVersion == "7.3.0")
        #expect(service.shouldPresentUpdatePrompt)
    }

    @MainActor
    @Test func updateDecisionDoesNotShowWhenCurrentVersionMeetsMinimum() async {
        let service = AppUpdateService(
            minimumVersionProvider: StubMinimumVersionProvider(result: .success("7.3.0")),
            appVersionProvider: StubAppVersionProvider(version: "7.3.0")
        )

        await service.checkForUpdate()

        #expect(service.availableUpdate == nil)
        #expect(!service.shouldPresentUpdatePrompt)
    }

    @MainActor
    @Test func updateDecisionFailsOpenWhenRemoteConfigFetchFails() async {
        let service = AppUpdateService(
            minimumVersionProvider: StubMinimumVersionProvider(result: .failure(UpdateTestError.fetchFailed)),
            appVersionProvider: StubAppVersionProvider(version: "7.2.0")
        )

        await service.checkForUpdate()

        #expect(service.availableUpdate == nil)
        #expect(!service.shouldPresentUpdatePrompt)
    }

    @Test func versionComparatorTreatsPatchZeroAsSameVersion() {
        #expect(AppVersionComparator.compare("7.2.0", "7.2") == .orderedSame)
        #expect(!AppVersionComparator.isVersion("7.2.0", newerThan: "7.2"))
    }

    @Test func versionComparatorComparesMultiDigitSegmentsNumerically() {
        #expect(AppVersionComparator.isVersion("7.10.0", newerThan: "7.2.9"))
        #expect(AppVersionComparator.compare("7.2.9", "7.10.0") == .orderedAscending)
    }

    @Test func versionComparatorHandlesMajorAndPatchUpdates() {
        #expect(AppVersionComparator.isVersion("8", newerThan: "7.9.9"))
        #expect(AppVersionComparator.isVersion("7.2.1", newerThan: "7.2.0"))
        #expect(!AppVersionComparator.isVersion("7.2.0", newerThan: "7.2.1"))
    }

    @Test func versionComparatorDoesNotBlockForMalformedVersions() {
        #expect(!AppVersionComparator.isVersion("7.2.0", olderThan: "latest"))
        #expect(!AppVersionComparator.isVersion("debug", olderThan: "7.3.0"))
        #expect(!AppVersionComparator.isVersion("7..3", olderThan: "7.4.0"))
    }
}

private struct StubMinimumVersionProvider: AppMinimumVersionProviding {
    let result: Result<String, Error>

    func fetchMinimumRequiredVersion() async throws -> String {
        try result.get()
    }
}

private struct StubAppVersionProvider: AppVersionProviding {
    let version: String

    var currentAppVersion: String? {
        version
    }
}

private enum UpdateTestError: Error {
    case fetchFailed
}
