import Foundation

/// The kind of text transformation a `NodePatchOperation` should perform.
public enum NodePatchOperationType: String, Codable, Hashable {
    /// Discard all existing text and set the node section to `content`.
    case replaceAll = "replace_all"
    /// Locate the first occurrence of `target` and replace it with `content`.
    case replaceExact = "replace_exact"
    /// Insert `content` immediately before the first occurrence of `target`.
    case insertBeforeExact = "insert_before_exact"
    /// Insert `content` immediately after the first occurrence of `target`.
    case insertAfterExact = "insert_after_exact"
    /// Add `content` at the end of the existing text.
    case append
    /// Add `content` at the beginning of the existing text.
    case prepend
}

/// A single text transformation to apply to a node section (SRS or code).
public struct NodePatchOperation: Codable, Hashable {
    /// How the text should be modified.
    public let type: NodePatchOperationType
    /// The exact substring to locate for `replaceExact`, `insertBeforeExact`,
    /// and `insertAfterExact` operations. Unused by `replaceAll`, `append`, and `prepend`.
    public let target: String?
    /// The text to write as part of this operation.
    public let content: String

    public init(type: NodePatchOperationType, target: String? = nil, content: String) {
        self.type = type
        self.target = target
        self.content = content
    }
}

/// Errors that can occur when resolving a target node or applying patch operations.
public enum NodePatchError: LocalizedError, Hashable {
    /// No node with the expected `NodeRole` exists on the canvas.
    case missingNode(NodeRole)
    /// A specific node UUID was requested but not found in the active project.
    case missingNodeID(UUID)
    /// An exact-match operation could not find its target substring in the existing text.
    case conflict(String)

    public var errorDescription: String? {
        switch self {
        case .missingNode(let role):
            return LocalizationManager.shared.localizedString("Missing %@ node.", arguments: [role.localizedDisplayName])
        case .missingNodeID:
            return LocalizationManager.shared.localizedString("The targeted node could not be found.")
        case .conflict(let description):
            return LocalizationManager.shared.localizedString(description)
        }
    }
}

/// Result of applying patch operations for review staging.
public struct NodePatchResolvedApply: Hashable {
    public let resultText: String
    public let canonicalOperations: [NodePatchOperation]
}

/// A before-and-after snapshot produced by `NodePatchEngine.preview`.
/// The UI presents this to the user before committing any change.
public struct NodePatchPreview: Hashable {
    /// The node that would be modified.
    public let nodeID: UUID
    /// The role of that node (e.g. `.miniApp`).
    public let role: NodeRole
    /// Which section of the Mini-App is being patched.
    public let section: CoCaptainNodeEditProposal.MiniAppSection
    /// The section text before any operations are applied.
    public let originalText: String
    /// The section text after all operations have been applied in order.
    public let resultText: String
}

/// Applies deterministic text operations proposed by CoCaptain to canonical
/// project nodes. It previews changes first so the UI can keep edits
/// human-approved and conflict-aware.
public struct NodePatchEngine {
    public init() {}

    /// Looks up the target node either by explicit UUID or by canonical role.
    ///
    /// - When `nodeID` is provided the node must be a Mini-App; any other type
    ///   returns `nil` to prevent accidental edits to incompatible node types.
    /// - When `nodeID` is absent the canvas is searched for the first node whose
    ///   role matches and is marked as an editable canonical role.
    @MainActor
    public func resolveNode(nodeID: UUID? = nil, for role: NodeRole, in store: ProjectStore) -> SpatialNode? {
        if let nodeID {
            guard let node = store.nodes.first(where: { $0.id == nodeID }),
                  node.type == .miniApp else {
                return nil
            }
            return node
        }
        guard role.isEditableCanonicalRole else { return nil }
        return store.nodes.first(where: { role.matches(node: $0) })
    }

    /// Computes the result of applying `operations` without persisting anything.
    @MainActor
    public func preview(
        nodeID: UUID? = nil,
        role: NodeRole,
        section: CoCaptainNodeEditProposal.MiniAppSection = .code,
        operations: [NodePatchOperation],
        in store: ProjectStore
    ) throws -> NodePatchPreview {
        guard let node = resolveNode(nodeID: nodeID, for: role, in: store) else {
            if let nodeID {
                throw NodePatchError.missingNodeID(nodeID)
            }
            throw NodePatchError.missingNode(role)
        }

        let originalText: String
        switch section {
        case .srs:
            originalText = node.miniApp?.srsText ?? ""
        case .code:
            originalText = node.miniApp?.codeText ?? ""
        }
        let resultText = try apply(operations: operations, to: originalText)
        return NodePatchPreview(nodeID: node.id, role: node.role, section: section, originalText: originalText, resultText: resultText)
    }

    /// Previews a patch and returns canonical `replace_all` operations for review/apply.
    @MainActor
    public func previewResolving(
        nodeID: UUID? = nil,
        role: NodeRole,
        section: CoCaptainNodeEditProposal.MiniAppSection = .code,
        operations: [NodePatchOperation],
        in store: ProjectStore
    ) throws -> (preview: NodePatchPreview, canonicalOperations: [NodePatchOperation]) {
        guard let node = resolveNode(nodeID: nodeID, for: role, in: store) else {
            if let nodeID {
                throw NodePatchError.missingNodeID(nodeID)
            }
            throw NodePatchError.missingNode(role)
        }

        let originalText: String
        switch section {
        case .srs:
            originalText = node.miniApp?.srsText ?? ""
        case .code:
            originalText = node.miniApp?.codeText ?? ""
        }

        let resolved = try applyResolvingTargets(operations: operations, to: originalText)
        let preview = NodePatchPreview(
            nodeID: node.id,
            role: node.role,
            section: section,
            originalText: originalText,
            resultText: resolved.resultText
        )
        return (preview, resolved.canonicalOperations)
    }

    /// Applies operations and returns a single canonical `replace_all` for staging.
    public func applyResolvingTargets(
        operations: [NodePatchOperation],
        to text: String
    ) throws -> NodePatchResolvedApply {
        let resultText = try apply(operations: operations, to: text)
        return NodePatchResolvedApply(
            resultText: resultText,
            canonicalOperations: [NodePatchOperation(type: .replaceAll, content: resultText)]
        )
    }

    /// Applies operations in order. Exact operations resolve targets with flexible
    /// matching (case, whitespace, punctuation) but still conflict when ambiguous.
    public func apply(operations: [NodePatchOperation], to text: String) throws -> String {
        var updatedText = text

        for operation in operations {
            switch operation.type {
            case .replaceAll:
                updatedText = operation.content
            case .replaceExact:
                guard let target = operation.target,
                      let range = PatchTargetMatcher.uniqueRange(of: target, in: updatedText) else {
                    throw NodePatchError.conflict("Could not find exact text to replace.")
                }
                updatedText.replaceSubrange(range, with: operation.content)
            case .insertBeforeExact:
                guard let target = operation.target,
                      let range = PatchTargetMatcher.uniqueRange(of: target, in: updatedText) else {
                    throw NodePatchError.conflict("Could not find exact text to insert before.")
                }
                updatedText.insert(contentsOf: operation.content, at: range.lowerBound)
            case .insertAfterExact:
                guard let target = operation.target,
                      let range = PatchTargetMatcher.uniqueRange(of: target, in: updatedText) else {
                    throw NodePatchError.conflict("Could not find exact text to insert after.")
                }
                updatedText.insert(contentsOf: operation.content, at: range.upperBound)
            case .append:
                updatedText += operation.content
            case .prepend:
                updatedText = operation.content + updatedText
            }
        }

        return updatedText
    }
}

/// Flexible target matching for patch operations. Returns a range only when the
/// match is unique to avoid editing the wrong occurrence.
private enum PatchTargetMatcher {
    static func uniqueRange(of target: String, in text: String) -> Range<String.Index>? {
        guard !target.isEmpty else { return nil }

        if let range = singleLiteralRange(of: target, in: text, options: []) { return range }
        if let range = singleLiteralRange(
            of: target,
            in: text,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) { return range }
        if let range = tokenSequenceRange(of: target, in: text) { return range }
        return whitespaceFlexibleRange(of: target, in: text)
    }

    private static func singleLiteralRange(
        of target: String,
        in text: String,
        options: String.CompareOptions
    ) -> Range<String.Index>? {
        var match: Range<String.Index>?
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(of: target, options: options, range: searchStart..<text.endIndex) {
            if match != nil {
                return nil
            }
            match = range
            searchStart = range.upperBound
        }

        return match
    }

    private static func whitespaceFlexibleRange(of target: String, in text: String) -> Range<String.Index>? {
        let targetWords = normalizedWords(in: target)
        guard !targetWords.isEmpty else { return nil }

        let pattern = targetWords
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "\\s+")
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard matches.count == 1, let match = matches.first,
              let range = Range(match.range, in: text) else {
            return nil
        }

        return range
    }

    private static func tokenSequenceRange(of target: String, in text: String) -> Range<String.Index>? {
        let targetTokens = alphanumericTokens(in: target)
        guard !targetTokens.isEmpty else { return nil }

        let sourceTokens = tokenSpans(in: text)
        guard sourceTokens.count >= targetTokens.count else { return nil }

        var matches: [Range<String.Index>] = []

        for startIndex in 0...(sourceTokens.count - targetTokens.count) {
            let slice = sourceTokens[startIndex..<(startIndex + targetTokens.count)]
            let sliceTokens = slice.map(\.token)
            guard zip(sliceTokens, targetTokens).allSatisfy({
                $0.caseInsensitiveCompare($1) == .orderedSame
            }) else {
                continue
            }

            let first = slice.first!.range.lowerBound
            var lastUpper = slice.last!.range.upperBound
            while lastUpper < text.endIndex, text[lastUpper].isPunctuation {
                lastUpper = text.index(after: lastUpper)
            }
            matches.append(first..<lastUpper)
        }

        guard matches.count == 1 else { return nil }
        return matches[0]
    }

    private static func normalizedWords(in text: String) -> [String] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    private static func alphanumericTokens(in text: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for character in text {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private struct TokenSpan {
        let token: String
        let range: Range<String.Index>
    }

    private static func tokenSpans(in text: String) -> [TokenSpan] {
        var spans: [TokenSpan] = []
        var tokenStart: String.Index?
        var current = ""

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character.isLetter || character.isNumber {
                if tokenStart == nil {
                    tokenStart = index
                }
                current.append(character)
            } else if let start = tokenStart {
                spans.append(TokenSpan(token: current, range: start..<index))
                tokenStart = nil
                current = ""
            }
            index = text.index(after: index)
        }

        if let start = tokenStart {
            spans.append(TokenSpan(token: current, range: start..<text.endIndex))
        }

        return spans
    }
}
