import Foundation

enum VerifiedCodingLoopFeature {
    static let enabledKey = "cocaptain.verifiedCodingLoopEnabled"

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            return UserDefaults.standard.bool(forKey: enabledKey)
        }

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            NSClassFromString("XCTestCase") != nil {
            return false
        }

#if DEBUG
        return true
#else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
#endif
    }
}

/// Rollout gate for native function-call node edits (`propose_node_edit` /
/// `ask_clarifying_question`). Enabled by default in Debug and TestFlight,
/// disabled in production App Store builds, overridable via UserDefaults.
enum NodeEditToolsFeature {
    static let enabledKey = "cocaptain.nodeEditToolsEnabled"

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            return UserDefaults.standard.bool(forKey: enabledKey)
        }

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            NSClassFromString("XCTestCase") != nil {
            return false
        }

#if DEBUG
        return true
#else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
#endif
    }
}
