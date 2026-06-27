import Foundation

/// Sanitizes Mini-App node titles into GitHub-compatible repository names.
enum PublishRepoNaming {
    static func repositoryName(nodeTitle: String, nodeID: UUID) -> String {
        let shortID = nodeID.uuidString.prefix(6).lowercased()
        let sanitized = sanitize(nodeTitle)
        if sanitized.isEmpty {
            return "caocap-miniapp-\(shortID)"
        }
        return "caocap-\(sanitized)-\(shortID)"
    }

    static func sanitize(_ title: String) -> String {
        let lowered = title.lowercased()
        let allowed = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(allowed)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String(collapsed.prefix(40))
    }
}
