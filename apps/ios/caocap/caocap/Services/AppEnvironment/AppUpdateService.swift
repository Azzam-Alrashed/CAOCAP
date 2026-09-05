import Foundation
import FirebaseRemoteConfig
import Observation
import OSLog

/// Bundles the information needed to present a forced-update prompt to the user.
struct AppUpdateInfo: Equatable {
    /// The version string of the currently installed build (e.g. `"1.2.3"`).
    let currentVersion: String
    /// The minimum version the server requires; older builds must update.
    let minimumRequiredVersion: String
    /// Direct link to the app's page on the App Store.
    let appStoreURL: URL
}

/// Compares semantic version strings using component-by-component numeric ordering.
/// Strings that are not entirely numeric dot-separated segments are treated as invalid
/// and all comparisons involving them return `false`.
enum AppVersionComparator {
    /// Returns `true` when `candidate` is strictly older than `required`.
    static func isVersion(_ candidate: String, olderThan required: String) -> Bool {
        guard isValid(candidate), isValid(required) else { return false }
        return compare(candidate, required) == .orderedAscending
    }

    /// Returns `true` when `candidate` is strictly newer than `current`.
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        guard isValid(candidate), isValid(current) else { return false }
        return compare(candidate, current) == .orderedDescending
    }

    /// Compares two version strings component by component.
    /// Missing trailing components are treated as `0` so `"1.2"` equals `"1.2.0"`.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = normalizedParts(from: lhs)
        let rhsParts = normalizedParts(from: rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let lhsPart = index < lhsParts.count ? lhsParts[index] : 0
            let rhsPart = index < rhsParts.count ? rhsParts[index] : 0

            if lhsPart > rhsPart {
                return .orderedDescending
            }

            if lhsPart < rhsPart {
                return .orderedAscending
            }
        }

        return .orderedSame
    }

    /// Returns `true` if every `.`-separated component is a non-empty digit string.
    static func isValid(_ version: String) -> Bool {
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return false }

        return components.allSatisfy { component in
            !component.isEmpty && component.allSatisfy(\.isNumber)
        }
    }

    private static func normalizedParts(from version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}

/// Provides the minimum required app version from a remote source.
protocol AppMinimumVersionProviding {
    func fetchMinimumRequiredVersion() async throws -> String
}

/// Provides the current installed app version string.
protocol AppVersionProviding {
    var currentAppVersion: String? { get }
}

extension Bundle: AppVersionProviding {
    /// Reads `CFBundleShortVersionString` from the main bundle's `Info.plist`.
    var currentAppVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

/// Fetches the minimum required iOS version from Firebase Remote Config.
/// The value is stored under the `ios_min_version` parameter key.
struct RemoteConfigMinimumVersionProvider: AppMinimumVersionProviding {
    private let remoteConfig: RemoteConfig
    private let parameterKey = "ios_min_version"

    init(remoteConfig: RemoteConfig = .remoteConfig()) {
        self.remoteConfig = remoteConfig
        self.remoteConfig.setDefaults([parameterKey: "" as NSObject])
    }

    func fetchMinimumRequiredVersion() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            remoteConfig.fetchAndActivate { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = remoteConfig.configValue(forKey: parameterKey).stringValue
                continuation.resume(returning: value)
            }
        }
    }
}

/// The central coordinator that compares the installed app version against
/// the remote minimum version requirement to determine if a forced update is necessary.
@MainActor
@Observable
final class AppUpdateService {
    static let shared = AppUpdateService()
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/caocap/id1447742145")!

    private let logger = Logger(subsystem: "com.caocap.app", category: "AppUpdateService")
    private let minimumVersionProvider: AppMinimumVersionProviding
    private let appVersionProvider: AppVersionProviding

    private(set) var availableUpdate: AppUpdateInfo?
    /// `true` while the update check is in progress.
    private(set) var isChecking = false

    /// `true` when `availableUpdate` is non-nil and the UI should present the prompt.
    var shouldPresentUpdatePrompt: Bool {
        availableUpdate != nil
    }

    init(
        minimumVersionProvider: AppMinimumVersionProviding = RemoteConfigMinimumVersionProvider(),
        appVersionProvider: AppVersionProviding = Bundle.main
    ) {
        self.minimumVersionProvider = minimumVersionProvider
        self.appVersionProvider = appVersionProvider
    }

    /// Fetches the server-mandated minimum version and updates `availableUpdate`.
    ///
    /// No-ops if a check is already in flight. Sets `availableUpdate = nil` when
    /// the current version meets the requirement, or when the Remote Config fetch
    /// fails — avoiding a forced-update prompt due to transient network errors.
    func checkForUpdate() async {
        guard !isChecking else { return }
        guard let currentVersion = appVersionProvider.currentAppVersion,
              AppVersionComparator.isValid(currentVersion) else {
            logger.warning("Skipping update check because app version metadata is missing or invalid.")
            return
        }

        isChecking = true
        defer { isChecking = false }

        do {
            let minimumRequiredVersion = try await minimumVersionProvider.fetchMinimumRequiredVersion()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard AppVersionComparator.isVersion(currentVersion, olderThan: minimumRequiredVersion) else {
                availableUpdate = nil
                return
            }

            availableUpdate = AppUpdateInfo(
                currentVersion: currentVersion,
                minimumRequiredVersion: minimumRequiredVersion,
                appStoreURL: Self.appStoreURL
            )
        } catch {
            logger.error("Remote Config update check failed: \(error.localizedDescription)")
            availableUpdate = nil
        }
    }
}
