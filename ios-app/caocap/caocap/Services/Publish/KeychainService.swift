import Foundation
import Security

/// Secure storage for publish OAuth tokens (e.g. GitHub publish access).
enum KeychainService {
    static let githubPublishTokenAccount = "GitHubPublishAccessToken"

    @discardableResult
    static func save(token: String, for account: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData
        ]

        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func getToken(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    @discardableResult
    static func deleteToken(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
