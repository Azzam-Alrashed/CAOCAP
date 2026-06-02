import Foundation
import FirebaseRemoteConfig
import Observation
import OSLog

struct AppUpdateInfo: Equatable {
    let currentVersion: String
    let minimumRequiredVersion: String
    let appStoreURL: URL
}

enum AppVersionComparator {
    static func isVersion(_ candidate: String, olderThan required: String) -> Bool {
        guard isValid(candidate), isValid(required) else { return false }
        return compare(candidate, required) == .orderedAscending
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        guard isValid(candidate), isValid(current) else { return false }
        return compare(candidate, current) == .orderedDescending
    }

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

protocol AppMinimumVersionProviding {
    func fetchMinimumRequiredVersion() async throws -> String
}

protocol AppVersionProviding {
    var currentAppVersion: String? { get }
}

extension Bundle: AppVersionProviding {
    var currentAppVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

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

@MainActor
@Observable
final class AppUpdateService {
    static let shared = AppUpdateService()
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/caocap/id1447742145")!

    private let logger = Logger(subsystem: "com.caocap.app", category: "AppUpdateService")
    private let minimumVersionProvider: AppMinimumVersionProviding
    private let appVersionProvider: AppVersionProviding

    private(set) var availableUpdate: AppUpdateInfo?
    private(set) var isChecking = false

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
