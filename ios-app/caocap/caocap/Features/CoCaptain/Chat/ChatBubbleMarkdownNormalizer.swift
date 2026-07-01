import Foundation

/// Repairs common assistant formatting issues before markdown rendering.
enum ChatBubbleMarkdownNormalizer {
  /// Inserts paragraph breaks when the model glues section titles or numbered
  /// items onto the previous sentence without newlines.
  static func normalizeAssistantText(_ text: String) -> String {
    var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !result.isEmpty else { return result }

    result = result.replacingOccurrences(
      of: #"\.([A-Z][^\n.]{2,60}:)"#,
      with: ".\n\n$1",
      options: .regularExpression
    )

    result = result.replacingOccurrences(
      of: #"(?<=[.!?])\s+(\d+\.\s)"#,
      with: "\n\n$1",
      options: .regularExpression
    )

    return result
  }
}
