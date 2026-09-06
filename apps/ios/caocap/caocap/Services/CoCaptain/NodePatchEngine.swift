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

/// One possible location for an ambiguous patch target. Presented to the user
/// as a tappable choice so a multi-match edit never dead-ends.
///
/// `contextText` is a slice of the original section text that occurs exactly
/// once, which makes re-resolution deterministic after the user picks it.
public struct PatchMatchCandidate: Identifiable, Hashable, Codable {
    public let id: UUID
    /// Plain-language description shown on the choice button,
    /// e.g. `the heading: “Hello World!”`.
    public let label: String
    /// A slice of the original text guaranteed to appear exactly once.
    public let contextText: String
    /// UTF-16 offset of the matched span inside `contextText`.
    public let matchOffsetInContext: Int
    /// UTF-16 length of the matched span.
    public let matchLength: Int

    public init(
        id: UUID = UUID(),
        label: String,
        contextText: String,
        matchOffsetInContext: Int,
        matchLength: Int
    ) {
        self.id = id
        self.label = label
        self.contextText = contextText
        self.matchOffsetInContext = matchOffsetInContext
        self.matchLength = matchLength
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
    /// The target matched several places (or near-matched a few). The user can
    /// pick one of `candidates` to resolve the edit without re-prompting.
    case ambiguous(target: String, candidates: [PatchMatchCandidate])

    public var errorDescription: String? {
        switch self {
        case .missingNode(let role):
            return LocalizationManager.shared.localizedString("Missing %@ node.", arguments: [role.localizedDisplayName])
        case .missingNodeID:
            return LocalizationManager.shared.localizedString("The targeted node could not be found.")
        case .conflict(let description):
            return LocalizationManager.shared.localizedString(description)
        case .ambiguous:
            return LocalizationManager.shared.localizedString(
                "I found a few places that could match. Pick the one you meant and I'll make the change."
            )
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
    /// The role of that node.
    public let role: NodeRole
    /// Which leftover HTML / SRS section the unused patch claimed to target.
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
    /// - When `nodeID` is provided, look up that card.
    /// - When `nodeID` is absent, no leftover HTML role is editable, so this returns nil.
    @MainActor
    public func resolveNode(nodeID: UUID? = nil, for role: NodeRole, in store: ProjectStore) -> SpatialNode? {
        if let nodeID {
            return store.nodes.first(where: { $0.id == nodeID })
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

        let originalText = ""
        _ = section
        let resultText = try apply(operations: operations, to: originalText)
        return NodePatchPreview(nodeID: node.id, role: node.role, section: section, originalText: originalText, resultText: resultText)
    }

    /// Previews a patch and returns canonical `replace_all` operations for review/apply.
    ///
    /// - Parameter candidate: When the user has picked a `PatchMatchCandidate`
    ///   from a clarification prompt, pass it here so ambiguous targets resolve
    ///   to the chosen location.
    @MainActor
    public func previewResolving(
        nodeID: UUID? = nil,
        role: NodeRole,
        section: CoCaptainNodeEditProposal.MiniAppSection = .code,
        operations: [NodePatchOperation],
        in store: ProjectStore,
        choosing candidate: PatchMatchCandidate? = nil
    ) throws -> (preview: NodePatchPreview, canonicalOperations: [NodePatchOperation]) {
        guard let node = resolveNode(nodeID: nodeID, for: role, in: store) else {
            if let nodeID {
                throw NodePatchError.missingNodeID(nodeID)
            }
            throw NodePatchError.missingNode(role)
        }

        let originalText = ""
        _ = section
        let resolved = try applyResolvingTargets(operations: operations, to: originalText, choosing: candidate)
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
        to text: String,
        choosing candidate: PatchMatchCandidate? = nil
    ) throws -> NodePatchResolvedApply {
        let resultText = try apply(operations: operations, to: text, choosing: candidate)
        return NodePatchResolvedApply(
            resultText: resultText,
            canonicalOperations: [NodePatchOperation(type: .replaceAll, content: resultText)]
        )
    }

    /// Applies operations in order. Exact operations resolve targets with flexible
    /// matching (semantic aliases, case, whitespace, punctuation). When a target
    /// matches several places, the error carries pickable candidates instead of
    /// dead-ending.
    public func apply(operations: [NodePatchOperation], to text: String) throws -> String {
        try apply(operations: operations, to: text, choosing: nil)
    }

    /// Same as `apply(operations:to:)` but resolves ambiguous or near-miss
    /// targets to the user's chosen candidate when one is provided.
    public func apply(
        operations: [NodePatchOperation],
        to text: String,
        choosing candidate: PatchMatchCandidate?
    ) throws -> String {
        var updatedText = text
        // Candidates carry offsets into the original text, so they are only
        // offered (or honored) before any operation has modified the text.
        var textIsUnmodified = true

        for operation in operations {
            switch operation.type {
            case .replaceAll:
                updatedText = operation.content
            case .replaceExact:
                let range = try resolveTargetRange(
                    operation.target,
                    in: updatedText,
                    offerCandidates: textIsUnmodified,
                    choosing: candidate
                )
                updatedText.replaceSubrange(range, with: operation.content)
            case .insertBeforeExact:
                let range = try resolveTargetRange(
                    operation.target,
                    in: updatedText,
                    offerCandidates: textIsUnmodified,
                    choosing: candidate
                )
                updatedText.insert(contentsOf: operation.content, at: range.lowerBound)
            case .insertAfterExact:
                let range = try resolveTargetRange(
                    operation.target,
                    in: updatedText,
                    offerCandidates: textIsUnmodified,
                    choosing: candidate
                )
                updatedText.insert(contentsOf: operation.content, at: range.upperBound)
            case .append:
                updatedText += operation.content
            case .prepend:
                updatedText = operation.content + updatedText
            }
            textIsUnmodified = false
        }

        return updatedText
    }

    // MARK: - Target resolution

    private func resolveTargetRange(
        _ target: String?,
        in text: String,
        offerCandidates: Bool,
        choosing candidate: PatchMatchCandidate?
    ) throws -> Range<String.Index> {
        guard let target, !target.isEmpty else {
            throw NodePatchError.conflict(Self.notFoundMessage)
        }

        switch PatchTargetMatcher.resolve(target: target, in: text) {
        case .unique(let range):
            return range
        case .ambiguous(let ranges):
            if let candidate, let chosenRange = candidateRange(for: candidate, in: text) {
                return chosenRange
            }
            if offerCandidates {
                let candidates = makeCandidates(from: ranges, in: text)
                if !candidates.isEmpty {
                    throw NodePatchError.ambiguous(target: target, candidates: candidates)
                }
            }
            throw NodePatchError.conflict(Self.multipleMatchesMessage)
        case .none:
            if let candidate, let chosenRange = candidateRange(for: candidate, in: text) {
                return chosenRange
            }
            if offerCandidates {
                let nearRanges = PatchTargetMatcher.nearMatchRanges(of: target, in: text)
                let candidates = makeCandidates(from: nearRanges, in: text)
                if !candidates.isEmpty {
                    throw NodePatchError.ambiguous(target: target, candidates: candidates)
                }
            }
            throw NodePatchError.conflict(Self.notFoundMessage)
        }
    }

    private static let notFoundMessage =
        "I couldn't find that exact text in your app, so nothing was changed. Tell me what you'd like to change and I'll take another look."
    private static let multipleMatchesMessage =
        "That text appears in more than one place and I don't want to change the wrong one. Try describing the exact spot you mean."

    /// Recovers the chosen candidate's match range from the current text.
    /// Returns `nil` when the unique context can no longer be found.
    private func candidateRange(for candidate: PatchMatchCandidate, in text: String) -> Range<String.Index>? {
        let contextMatches = PatchTargetMatcher.literalMatches(
            of: candidate.contextText,
            in: text,
            options: []
        )
        guard contextMatches.count == 1, let context = contextMatches.first else { return nil }

        let contextStart = context.lowerBound.utf16Offset(in: text)
        let startOffset = contextStart + candidate.matchOffsetInContext
        let endOffset = startOffset + candidate.matchLength
        guard endOffset <= text.utf16.count, startOffset >= 0, startOffset <= endOffset else { return nil }

        let start = String.Index(utf16Offset: startOffset, in: text)
        let end = String.Index(utf16Offset: endOffset, in: text)
        guard start <= end, start >= context.lowerBound, end <= context.upperBound else { return nil }
        return start..<end
    }

    // MARK: - Candidate construction

    /// Turns raw match ranges into user-pickable candidates. Each candidate's
    /// context is grown line by line until it is unique within the text so a
    /// later pick can re-resolve deterministically.
    private func makeCandidates(
        from ranges: [Range<String.Index>],
        in text: String
    ) -> [PatchMatchCandidate] {
        var candidates: [PatchMatchCandidate] = []

        for range in ranges.prefix(4) {
            guard let context = uniqueContext(for: range, in: text) else { continue }

            let contextStart = context.lowerBound.utf16Offset(in: text)
            let matchStart = range.lowerBound.utf16Offset(in: text)
            let matchEnd = range.upperBound.utf16Offset(in: text)

            candidates.append(
                PatchMatchCandidate(
                    label: candidateLabel(for: range, in: text),
                    contextText: String(text[context]),
                    matchOffsetInContext: matchStart - contextStart,
                    matchLength: matchEnd - matchStart
                )
            )
        }

        return candidates
    }

    /// Expands from the match's line outward until the slice occurs exactly
    /// once in `text`, or gives up after a few expansions.
    private func uniqueContext(for range: Range<String.Index>, in text: String) -> Range<String.Index>? {
        var context = text.lineRange(for: range)

        for _ in 0..<6 {
            if isUniqueSlice(context, in: text) { return context }

            let lower = context.lowerBound > text.startIndex
                ? text.index(before: context.lowerBound)
                : context.lowerBound
            let upper = context.upperBound < text.endIndex
                ? text.index(after: context.upperBound)
                : context.upperBound
            let expanded = text.lineRange(for: lower..<upper)
            if expanded == context { return nil }
            context = expanded
        }

        return isUniqueSlice(context, in: text) ? context : nil
    }

    private func isUniqueSlice(_ slice: Range<String.Index>, in text: String) -> Bool {
        let sliceText = String(text[slice])
        guard !sliceText.isEmpty else { return false }
        return PatchTargetMatcher.literalMatches(of: sliceText, in: text, options: []).count == 1
    }

    /// Builds a plain-language button label like `the heading: “Hello World!”`.
    private func candidateLabel(for range: Range<String.Index>, in text: String) -> String {
        let friendlyPlace = LocalizationManager.shared.localizedString(
            friendlyPlaceKey(for: range, in: text)
        )
        let snippet = snippetText(String(text[range]))
        guard !snippet.isEmpty else { return friendlyPlace }
        return "\(friendlyPlace): “\(snippet)”"
    }

    private func snippetText(_ raw: String) -> String {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard collapsed.count > 40 else { return collapsed }
        return String(collapsed.prefix(40)) + "…"
    }

    /// Infers a beginner-friendly name for the location by looking at the
    /// nearest enclosing HTML tag before the match.
    private func friendlyPlaceKey(for range: Range<String.Index>, in text: String) -> String {
        guard let tag = enclosingTagName(before: range.lowerBound, in: text) else {
            return "the text"
        }
        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            return "the heading"
        case "title":
            return "the browser tab title"
        case "button":
            return "the button"
        case "a":
            return "the link"
        case "p":
            return "the paragraph"
        case "li":
            return "the list item"
        default:
            return "the text"
        }
    }

    private func enclosingTagName(before index: String.Index, in text: String) -> String? {
        var cursor = index
        while cursor > text.startIndex {
            cursor = text.index(before: cursor)
            guard text[cursor] == "<" else { continue }

            var nameEnd = text.index(after: cursor)
            var name = ""
            while nameEnd < text.endIndex, text[nameEnd].isLetter || text[nameEnd].isNumber {
                name.append(text[nameEnd])
                nameEnd = text.index(after: nameEnd)
            }
            return name.isEmpty ? nil : name.lowercased()
        }
        return nil
    }
}

/// Flexible target matching for patch operations.
///
/// Resolution runs semantic aliases first (e.g. "title" means the page's H1
/// for non-technical users), then literal, case-insensitive, token-sequence,
/// and whitespace-flexible tiers. Each tier reports ambiguity explicitly so
/// callers can offer the user a choice instead of failing.
enum PatchTargetMatcher {
    enum Resolution {
        case unique(Range<String.Index>)
        case ambiguous([Range<String.Index>])
        case none
    }

    static func resolve(target: String, in text: String) -> Resolution {
        guard !target.isEmpty else { return .none }

        if let aliasResult = aliasResolution(target: target, in: text) {
            return aliasResult
        }

        let tiers: [() -> [Range<String.Index>]] = [
            { literalMatches(of: target, in: text, options: []) },
            { literalMatches(of: target, in: text, options: [.caseInsensitive, .diacriticInsensitive]) },
            { tokenSequenceMatches(of: target, in: text) },
            { whitespaceFlexibleMatches(of: target, in: text) }
        ]

        for tier in tiers {
            let matches = tier()
            if matches.count == 1 { return .unique(matches[0]) }
            if matches.count > 1 { return .ambiguous(matches) }
        }

        return .none
    }

    // MARK: - Semantic aliases

    /// Phrases non-technical users say when they mean the page's visible main
    /// heading. Keyed after lowercasing, collapsing whitespace, and stripping
    /// a leading "the ". Data-driven so more aliases/tags can be added later.
    private static let headingAliasTriggers: Set<String> = [
        "title", "page title", "app title", "main title", "big title",
        "headline", "main headline",
        "header", "heading", "main heading", "big heading",
        "big text"
    ]

    /// Resolves alias targets against `<h1>` inner text so "title" never hits
    /// the `<title>` tag. Returns `nil` (fall through to normal tiers) when the
    /// target is not an alias or the text has no `<h1>` at all.
    private static func aliasResolution(target: String, in text: String) -> Resolution? {
        let key = normalizedAliasKey(target)
        guard headingAliasTriggers.contains(key) else { return nil }

        let ranges = headingInnerRanges(in: text)
        if ranges.count == 1 { return .unique(ranges[0]) }
        if ranges.count > 1 { return .ambiguous(ranges) }
        return nil
    }

    private static func normalizedAliasKey(_ target: String) -> String {
        var key = target
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if key.hasPrefix("the ") {
            key = String(key.dropFirst(4))
        }
        return key
    }

    /// All `<h1>...</h1>` inner-text ranges in document order.
    private static func headingInnerRanges(in text: String) -> [Range<String.Index>] {
        let pattern = "<h1\\b[^>]*>(.*?)</h1>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap {
            Range($0.range(at: 1), in: text)
        }
    }

    // MARK: - Matching tiers

    static func literalMatches(
        of target: String,
        in text: String,
        options: String.CompareOptions
    ) -> [Range<String.Index>] {
        var matches: [Range<String.Index>] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(of: target, options: options, range: searchStart..<text.endIndex) {
            matches.append(range)
            searchStart = range.upperBound
        }

        return matches
    }

    private static func whitespaceFlexibleMatches(of target: String, in text: String) -> [Range<String.Index>] {
        let targetWords = normalizedWords(in: target)
        guard !targetWords.isEmpty else { return [] }

        let pattern = targetWords
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "\\s+")
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap {
            Range($0.range, in: text)
        }
    }

    private static func tokenSequenceMatches(of target: String, in text: String) -> [Range<String.Index>] {
        let targetTokens = alphanumericTokens(in: target)
        guard !targetTokens.isEmpty else { return [] }

        let sourceTokens = tokenSpans(in: text[...])
        guard sourceTokens.count >= targetTokens.count else { return [] }

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

        return matches
    }

    // MARK: - Near matches

    /// When nothing matches at all, finds up to three lines whose tokens
    /// overlap the target enough (>= 50%) to plausibly be what the user meant.
    /// Used to offer "did you mean one of these?" choices.
    static func nearMatchRanges(of target: String, in text: String) -> [Range<String.Index>] {
        let targetTokens = Set(alphanumericTokens(in: target).map { $0.lowercased() })
        guard !targetTokens.isEmpty else { return [] }

        var scored: [(score: Double, range: Range<String.Index>)] = []
        var lineStart = text.startIndex

        while lineStart < text.endIndex {
            let line = text.lineRange(for: lineStart..<lineStart)
            defer { lineStart = line.upperBound }

            let spans = tokenSpans(in: text[line])
            let overlapping = spans.filter { targetTokens.contains($0.token.lowercased()) }
            guard let first = overlapping.first, let last = overlapping.last else { continue }

            let matchedCount = Set(overlapping.map { $0.token.lowercased() }).count
            let score = Double(matchedCount) / Double(targetTokens.count)
            guard score >= 0.5 else { continue }

            scored.append((score, first.range.lowerBound..<last.range.upperBound))
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map(\.range)
    }

    // MARK: - Tokenization

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

    /// Token spans within a substring; ranges are valid in the parent string.
    private static func tokenSpans(in text: Substring) -> [TokenSpan] {
        var spans: [TokenSpan] = []
        var tokenStart: Substring.Index?
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
