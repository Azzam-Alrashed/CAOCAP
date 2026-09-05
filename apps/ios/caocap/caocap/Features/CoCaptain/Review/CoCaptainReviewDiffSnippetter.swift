import Foundation

/// Builds compact before/after windows around the first textual change so review
/// cards stay readable on compact widths instead of dumping entire Mini-App files.
enum CoCaptainReviewDiffSnippetter {
    static let maximumSnippetCharacters = 480
    static let contextLineRadius = 4

    struct Snippets: Equatable {
        let before: String
        let after: String
    }

    /// Returns focused snippets for a node-edit review. When texts are identical
    /// or empty, falls back to truncated full documents.
    static func makeSnippets(before: String, after: String) -> Snippets {
        let beforeLines = splitLines(before)
        let afterLines = splitLines(after)

        guard let change = firstChangeRange(beforeLines: beforeLines, afterLines: afterLines) else {
            return Snippets(
                before: truncate(before.trimmingCharacters(in: .whitespacesAndNewlines)),
                after: truncate(after.trimmingCharacters(in: .whitespacesAndNewlines))
            )
        }

        let beforeSnippet = window(
            lines: beforeLines,
            start: change.beforeStart,
            end: change.beforeEnd
        )
        let afterSnippet = window(
            lines: afterLines,
            start: change.afterStart,
            end: change.afterEnd
        )

        return Snippets(
            before: truncate(beforeSnippet),
            after: truncate(afterSnippet)
        )
    }

    private struct ChangeRange {
        let beforeStart: Int
        let beforeEnd: Int
        let afterStart: Int
        let afterEnd: Int
    }

    private static func splitLines(_ text: String) -> [String] {
        if text.isEmpty { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private static func firstChangeRange(
        beforeLines: [String],
        afterLines: [String]
    ) -> ChangeRange? {
        let prefix = zip(beforeLines, afterLines).prefix(while: { $0 == $1 }).count
        if prefix == beforeLines.count, prefix == afterLines.count {
            return nil
        }

        var beforeSuffix = 0
        var afterSuffix = 0
        while beforeSuffix < beforeLines.count - prefix,
              afterSuffix < afterLines.count - prefix,
              beforeLines[beforeLines.count - 1 - beforeSuffix]
                == afterLines[afterLines.count - 1 - afterSuffix] {
            beforeSuffix += 1
            afterSuffix += 1
        }

        let beforeStart = prefix
        let beforeEnd = max(beforeStart, beforeLines.count - beforeSuffix)
        let afterStart = prefix
        let afterEnd = max(afterStart, afterLines.count - afterSuffix)
        return ChangeRange(
            beforeStart: beforeStart,
            beforeEnd: beforeEnd,
            afterStart: afterStart,
            afterEnd: afterEnd
        )
    }

    private static func window(lines: [String], start: Int, end: Int) -> String {
        guard !lines.isEmpty else { return "" }
        let lower = max(0, start - contextLineRadius)
        let upper = min(lines.count, end + contextLineRadius)
        guard lower < upper else { return "" }

        var parts: [String] = []
        if lower > 0 {
            parts.append("…")
        }
        parts.append(contentsOf: lines[lower..<upper])
        if upper < lines.count {
            parts.append("…")
        }
        return parts.joined(separator: "\n")
    }

    private static func truncate(_ text: String) -> String {
        guard text.count > maximumSnippetCharacters else { return text }
        return String(text.prefix(maximumSnippetCharacters)) + "\n[TRUNCATED]"
    }
}
