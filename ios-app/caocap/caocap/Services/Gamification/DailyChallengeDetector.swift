import Foundation

/// Inspects compiled Mini-App HTML for daily challenge completion.
public enum DailyChallengeDetector {
    public static let defaultTitle = "My App"
    public static let defaultBackgroundColor = "#0d0d0d"

    private static let titleRegex = /<title>\s*([^<]+?)\s*<\/title>/
    private static let backgroundRegex = /background(?:-color)?\s*:\s*([^;}\n]+)/
    private static let imageRegex = /<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>/

    public static func matchedChallengeIDs(in html: String) -> Set<String> {
        var matched = Set<String>()
        if matchesTitleChanged(html) {
            matched.insert("update_title")
        }
        if matchesBackgroundChanged(html) {
            matched.insert("change_background")
        }
        if matchesImageAdded(html) {
            matched.insert("add_image")
        }
        return matched
    }

    public static func matchesTitleChanged(_ html: String) -> Bool {
        guard let match = html.firstMatch(of: titleRegex) else { return false }
        let title = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && title.caseInsensitiveCompare(defaultTitle) != .orderedSame
    }

    public static func matchesBackgroundChanged(_ html: String) -> Bool {
        for match in html.matches(of: backgroundRegex) {
            let raw = String(match.1)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if raw.isEmpty { continue }
            if raw == defaultBackgroundColor.lowercased() { continue }
            if raw == "0d0d0d" { continue }
            if raw == "rgb(13, 13, 13)" { continue }
            return true
        }
        return false
    }

    public static func matchesImageAdded(_ html: String) -> Bool {
        guard let match = html.firstMatch(of: imageRegex) else { return false }
        return !String(match.1).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
