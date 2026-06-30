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
