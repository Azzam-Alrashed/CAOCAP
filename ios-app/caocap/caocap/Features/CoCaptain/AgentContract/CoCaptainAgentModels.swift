import Foundation

/// Identifies the portion of the canvas that a CoCaptain agent session targets.
///
/// The scope controls both which context is serialised for the model and
/// which chat history is maintained — project-level and node-level sessions
/// are kept independent so switching nodes doesn't pollute the project chat.
public enum CoCaptainAgentScope: Hashable {
    /// The entire active project canvas.
    case project
    /// A single named node within the canvas, identified by its UUID.
    case node(UUID)

    /// A stable string suitable for keying per-scope state in a dictionary
    /// or persisted store (e.g. scroll-position keying in the timeline).
    public var storageKey: String {
        switch self {
        case .project:
            return "project"
        case .node(let id):
            return "node:\(id.uuidString)"
        }
    }
}

/// The lifecycle state of one CoCaptain agent turn, used by the view model
/// to gate UI interactions and display appropriate loading/feedback states.
public enum AgentExecutionState: Equatable {
    /// No request is in progress; the assistant is ready to accept input.
    case idle
    /// The model is streaming a response.
    case thinking
    /// Safe actions are being executed against the active project store.
    case applying
    /// The model produced review items that the user must approve or reject
    /// before changes are committed.
    case awaitingReview
    /// A terminal error occurred during the turn; the associated string
    /// carries a user-facing description.
    case error(String)
}

/// A single app-level action emitted by the model, referencing a registered
/// `AppActionID` by its raw string and optional key-value arguments.
///
/// Actions arrive as either safe (auto-executed) or pending (user-reviewed)
/// depending on the enclosing XML block or function-call `executionMode`.
public struct CoCaptainAgentAction: Codable, Hashable {
    /// The raw string identifier that maps to a registered `AppActionID`.
    public let actionID: String
    /// Optional arguments passed to the action handler (e.g. `["url": "..."]`).
    public let args: [String: String]?

    public init(actionID: String, args: [String: String]? = nil) {
        self.actionID = actionID
        self.args = args
    }

    private enum CodingKeys: String, CodingKey {
        // The wire format uses camelCase; the struct uses the canonical Swift name.
        case actionID = "actionId"
        case args
    }
}

/// A model-proposed edit to one section of a canvas node.
///
/// The proposal is held in a `ReviewBundleItem` until the user approves it,
/// at which point `NodePatchEngine` applies the operations against the live
/// project store.
public struct CoCaptainNodeEditProposal: Codable, Hashable {
    /// The two editable sections of a Mini-App node that the model can target.
    public enum MiniAppSection: String, Codable, Hashable {
        /// The Software Requirements Specification / documentation section.
        case srs
        /// The executable source-code section.
        case code
    }

    /// The specific node to edit, or `nil` when the model omits the ID and
    /// the coordinator resolves it by role matching against the active store.
    public let nodeID: UUID?
    /// The role the target node must have (e.g. `.miniApp`).
    public let role: NodeRole
    /// Which of the node's text sections the operations should be applied to.
    public let section: MiniAppSection
    /// A short human-readable description surfaced in the review UI.
    public let summary: String
    /// The ordered sequence of patch operations to apply when accepted.
    public let operations: [NodePatchOperation]

    public init(nodeID: UUID? = nil, role: NodeRole = .miniApp, section: MiniAppSection = .code, summary: String, operations: [NodePatchOperation]) {
        self.nodeID = nodeID
        self.role = role
        self.section = section
        self.summary = summary
        self.operations = operations
    }

    private enum CodingKeys: String, CodingKey {
        case nodeID = "nodeId"
        case role
        case section
        case summary
        case operations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeID = try container.decodeIfPresent(UUID.self, forKey: .nodeID)
        // Default to .miniApp / .code so the model can omit these fields for the common case.
        self.role = try container.decodeIfPresent(NodeRole.self, forKey: .role) ?? .miniApp
        self.section = try container.decodeIfPresent(MiniAppSection.self, forKey: .section) ?? .code
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.operations = try container.decode([NodePatchOperation].self, forKey: .operations)
    }
}

/// The decoded, structured output from one CoCaptain model turn.
///
/// The payload separates the model's prose from its executable intent.
/// `safeActions` run immediately (non-mutating, autonomous); `pendingActions`
/// and `nodeEdits` enter the review queue for explicit user approval.
public struct CoCaptainAgentPayload: Codable, Hashable {
    /// The chat-visible text the model produced alongside its actions.
    public let assistantMessage: String
    /// Actions that the coordinator may execute autonomously without user review
    /// because they are non-mutating or explicitly marked as safe.
    public let safeActions: [CoCaptainAgentAction]
    /// Actions that require explicit user approval before being dispatched.
    public let pendingActions: [CoCaptainAgentAction]
    /// Proposed edits to canvas nodes that must pass review before being applied.
    public let nodeEdits: [CoCaptainNodeEditProposal]

    public init(
        assistantMessage: String,
        safeActions: [CoCaptainAgentAction] = [],
        pendingActions: [CoCaptainAgentAction] = [],
        nodeEdits: [CoCaptainNodeEditProposal] = []
    ) {
        self.assistantMessage = assistantMessage
        self.safeActions = safeActions
        self.pendingActions = pendingActions
        self.nodeEdits = nodeEdits
    }
}

/// A Gemini function-call payload delivered via the streaming API.
///
/// When the model invokes a declared tool (e.g. `request_app_action`), the
/// SDK surfaces it as a function call alongside or instead of text. The
/// composite adapter merges these with any XML-fenced actions.
public struct CoCaptainAgentFunctionCall: Hashable {
    /// The registered tool name as declared in the function declarations schema.
    public let name: String
    /// The arguments the model supplied for this invocation.
    public let arguments: [String: String]
    /// An opaque ID assigned by the model; used to deduplicate duplicate
    /// function-call events that can arrive during streaming.
    public let id: String?

    public init(name: String, arguments: [String: String], id: String? = nil) {
        self.name = name
        self.arguments = arguments
        self.id = id
    }
}

/// A single event emitted by the LLM streaming API during one assistant turn.
public enum CoCaptainLLMStreamEvent: Hashable {
    /// An incremental text chunk to be appended to the running response buffer.
    case text(String)
    /// One or more function calls produced by the model in a single delta.
    case functionCalls([CoCaptainAgentFunctionCall])
}

public struct CoCaptainParsedResponse: Hashable {
    /// The text before any structured payload or code blocks.
    public let preamble: String
    public let payload: CoCaptainAgentPayload?
    public let diagnostic: String?

    public init(preamble: String, payload: CoCaptainAgentPayload?, diagnostic: String? = nil) {
        self.preamble = preamble
        self.payload = payload
        self.diagnostic = diagnostic
    }

    /// Backwards compatibility or merged view
    public var visibleText: String {
        if preamble.isEmpty {
            return payload?.assistantMessage ?? ""
        }
        return preamble
    }
}

/// Tracks the lifecycle of a single `PendingReviewItem` as the user
/// approves, rejects, or encounters a conflict.
public enum ReviewItemStatus: String, Hashable {
    /// The item has not yet been acted upon by the user.
    case pending
    /// The user approved the item and it was applied to the store.
    case applied
    /// The item could not be applied cleanly — e.g. the underlying node
    /// changed between when the model proposed the edit and when the user
    /// pressed Apply.
    case conflicted
    /// The user explicitly dismissed the item without applying it.
    case rejected

    /// A short localized label suitable for display in the review chip.
    public var localizedTitle: String {
        switch self {
        case .pending:
            return LocalizationManager.shared.localizedString("Pending")
        case .applied:
            return LocalizationManager.shared.localizedString("Applied")
        case .conflicted:
            return LocalizationManager.shared.localizedString("Conflicted")
        case .rejected:
            return LocalizationManager.shared.localizedString("Rejected")
        }
    }
}

/// A confirmation record that appears in the timeline after the coordinator
/// has automatically executed one or more safe app actions.
public struct ExecutionStatusItem: Identifiable, Hashable {
    public let id: UUID
    /// A comma-joined, human-readable list of the action titles that were run.
    public let summary: String

    public init(id: UUID = UUID(), summary: String) {
        self.id = id
        self.summary = summary
    }
}

/// An in-chat call-to-action card that nudges the user toward a specific app
/// action — for example, upgrading to a paid tier or enabling a feature.
public struct CoCaptainProductCTAItem: Identifiable, Hashable {
    public let id: UUID
    /// The bold headline displayed at the top of the CTA card.
    public let title: String
    /// Supporting copy explaining why the action is recommended.
    public let message: String
    /// Label of the primary action button.
    public let primaryButtonTitle: String
    /// The `AppActionID` that fires when the user taps the primary button.
    public let actionID: AppActionID

    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        primaryButtonTitle: String,
        actionID: AppActionID
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.actionID = actionID
    }
}

/// Describes the origin of a `PendingReviewItem`, driving how the
/// coordinator applies or rejects the item when the user acts on it.
public enum PendingReviewSource: Hashable {
    /// An app-level action (e.g. navigate, open settings) waiting for approval.
    case appAction(AppActionID, [String: String]? = nil)
    /// A proposed node text edit. `baseText` is captured at proposal time so
    /// `NodePatchEngine` can detect intervening changes and flag conflicts.
    case nodeEdit(role: NodeRole, section: CoCaptainNodeEditProposal.MiniAppSection, operations: [NodePatchOperation], baseText: String)
}

/// One actionable change within a `ReviewBundleItem`, representing either a
/// pending app action or a proposed node edit that the user can approve or reject.
public struct PendingReviewItem: Identifiable, Hashable {
    public let id: UUID
    /// The node the edit targets, if applicable. Used to scroll the canvas
    /// to the relevant node when the review card is tapped.
    public let targetNodeID: UUID?
    /// A short display name for the target (node title + section, or action title).
    public let targetLabel: String
    /// The model-authored description of what this change does.
    public let summary: String
    /// A short text snippet previewing the resulting content after the edit.
    /// Truncated to 280 characters for performance.
    public let preview: String
    /// Current lifecycle state of this item.
    public var status: ReviewItemStatus
    /// How this item was produced and how it should be applied or rejected.
    public let source: PendingReviewSource
    /// Human-readable explanation of why this item entered the conflicted state.
    /// Nil when the item has not yet conflicted.
    public var conflictDescription: String?

    public init(
        id: UUID = UUID(),
        targetNodeID: UUID? = nil,
        targetLabel: String,
        summary: String,
        preview: String,
        status: ReviewItemStatus = .pending,
        source: PendingReviewSource,
        conflictDescription: String? = nil
    ) {
        self.id = id
        self.targetNodeID = targetNodeID
        self.targetLabel = targetLabel
        self.summary = summary
        self.preview = preview
        self.status = status
        self.source = source
        self.conflictDescription = conflictDescription
    }
}

/// A named collection of `PendingReviewItem`s produced by a single agent turn.
///
/// The bundle appears as one timeline card with per-item Apply/Reject controls
/// and bulk Apply All / Reject All buttons.
public struct ReviewBundleItem: Identifiable, Hashable {
    public let id: UUID
    /// The heading shown at the top of the review card in the timeline.
    public let title: String
    /// The individual items within this bundle; mutable so the view model
    /// can update statuses in place without replacing the entire timeline entry.
    public var items: [PendingReviewItem]

    public init(
        id: UUID = UUID(),
        title: String = LocalizationManager.shared.localizedString("Pending changes"),
        items: [PendingReviewItem]
    ) {
        self.id = id
        self.title = title
        self.items = items
    }
}

/// A single chat message in the CoCaptain timeline, from either the user
/// or the assistant.
public struct ChatBubbleItem: Identifiable, Hashable {
    public let id: UUID
    /// The raw message text; mutable so streaming chunks can be appended
    /// to the last assistant bubble while the model is responding.
    public var text: String
    /// `true` when this bubble originates from the user, `false` for the assistant.
    public let isUser: Bool

    public init(id: UUID = UUID(), text: String, isUser: Bool) {
        self.id = id
        self.text = text
        self.isUser = isUser
    }

    /// The message rendered as an `AttributedString` with full markdown support.
    ///
    /// Attempts full markdown parsing first; if that fails (e.g. due to
    /// malformed input), falls back to inline-only syntax; and finally
    /// returns a plain-text `AttributedString` as a last resort so the
    /// UI never shows a blank bubble.
    public var markdownText: AttributedString {
        let fullOptions = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        if let attributed = try? AttributedString(markdown: text, options: fullOptions) {
            return attributed
        }

        let fallbackOptions = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: fallbackOptions)) ?? AttributedString(text)
    }
}

/// The discriminated content carried by a single row in the CoCaptain
/// timeline, covering all visual card types the UI can render.
public enum CoCaptainTimelineContent: Hashable {
    /// A user or assistant chat bubble.
    case message(ChatBubbleItem)
    /// A confirmation banner summarising auto-executed safe actions.
    case execution(ExecutionStatusItem)
    /// An in-chat upsell or feature nudge card.
    case productCTA(CoCaptainProductCTAItem)
    /// A set of proposed changes awaiting user review.
    case reviewBundle(ReviewBundleItem)
}

/// One identifiable row in the CoCaptain conversation timeline.
///
/// The `content` is mutable so the view model can patch streaming text or
/// update review-item statuses without rebuilding the whole list.
public struct CoCaptainTimelineItem: Identifiable, Hashable {
    public let id: UUID
    public var content: CoCaptainTimelineContent

    public init(id: UUID = UUID(), content: CoCaptainTimelineContent) {
        self.id = id
        self.content = content
    }
}

extension AttributedString {
    /// Convenience initialiser that creates a plain `AttributedString` from a
    /// `String` without requiring an explicit `stringLiteral:` label, matching
    /// the ergonomics of `String` init used in fallback paths.
    init(_ text: String) {
        self = AttributedString(stringLiteral: text)
    }
}
