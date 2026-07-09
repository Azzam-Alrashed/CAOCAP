import Foundation

/// Describes the conversational objective for a CoCaptain turn.
///
/// Most turns use the standard agent behavior. The onboarding welcome keeps
/// the response model-generated while giving the first interaction a focused
/// UX outcome.
public enum CoCaptainTurnPurpose: Hashable {
    case standard
    case onboardingWelcome
    case onboardingBuildHandoff
    case onboardingGuidedEdit

    var promptInstructions: String? {
        switch self {
        case .standard:
            return nil
        case .onboardingWelcome:
            return """
            Onboarding welcome objective:
            - This is the user's first CoCaptain interaction during onboarding.
            - Respond naturally to the user's greeting in 40 to 80 words.
            - Briefly explain that CoCaptain helps them build a working app while helping them understand the important decisions.
            - End with exactly one easy question asking what they would like to make.
            - You may include at most two short example ideas to make answering easier.
            - Match the language used by the user.
            - Do not mention nodes, SRS, patches, XML, Firebase, internal tools, or implementation details.
            - Do not request app actions, propose edits, or emit a `cocaptain_actions` block.
            - Do not claim the canvas contains anything that is not present in the supplied context.
            """
        case .onboardingBuildHandoff:
            return """
            Onboarding build handoff objective:
            - Treat the user's message as their initial direction for what they want to build.
            - In 20 to 50 words, briefly reflect their idea without inventing details.
            - Confirm that you are ready to begin and end with a natural transition back to the canvas to build it.
            - Match the language used by the user.
            - Do not ask a question or request more information.
            - Do not mention onboarding, internal tools, nodes, SRS, patches, XML, or Firebase.
            - Do not request app actions, propose edits, invoke tools, or emit a `cocaptain_actions` block.
            """
        case .onboardingGuidedEdit:
            return """
            Onboarding guided edit objective:
            - The user is editing the active demo mini-app during onboarding (for example the Tutorial Hello World mini-app, Pac-Man, or XO).
            - Prefer exactly one small visible CODE change, such as renaming the headline/title or adjusting headline styling.
            - For small existing mini-apps, use `replace_all` with the full updated single-file HTML document.
            - When renaming the Tutorial headline, update the `<h1>` text from `Hello World!` to the requested title.
            - Keep the change visible in the live preview and easy for a beginner to understand.
            - Do not modify SRS, Firebase, or any node other than the currently active mini-app.
            - Match the language used by the user when summarizing the change.
            """
        }
    }

    /// Selects how the coordinator executes this turn: full agentic pipeline or prose-only chat.
    var executionPolicy: CoCaptainTurnExecutionPolicy {
        switch self {
        case .standard, .onboardingGuidedEdit:
            return .agentic
        case .onboardingWelcome, .onboardingBuildHandoff:
            return .conversational
        }
    }

    var isConversationalTurn: Bool {
        executionPolicy.kind == .conversational
    }
}

/// Merges onboarding purpose with per-turn user intent to select execution behavior.
public struct CoCaptainTurnPlan: Equatable {
    public let purpose: CoCaptainTurnPurpose
    public let intent: CoCaptainTurnIntent

    public init(purpose: CoCaptainTurnPurpose, intent: CoCaptainTurnIntent) {
        self.purpose = purpose
        self.intent = intent
    }

    /// Onboarding purposes always stay conversational. Standard turns map intent
    /// to agentic or advisory execution.
    var effectivePolicy: CoCaptainTurnExecutionPolicy {
        switch purpose {
        case .onboardingWelcome, .onboardingBuildHandoff:
            return .conversational
        case .onboardingGuidedEdit:
            return .agentic
        case .standard:
            switch intent {
            case .mutatingWork:
                return .agentic
            case .advisory, .generalChat:
                return .advisory
            }
        }
    }
}

/// Controls whether a CoCaptain turn runs the full agent contract or stays conversational.
///
/// Derived from `CoCaptainTurnPlan` so prompt instructions and execution behavior
/// stay aligned in one place.
struct CoCaptainTurnExecutionPolicy: Equatable {
    enum Kind: Equatable {
        case conversational
        case agentic
        case advisory
    }

    let kind: Kind
    let expectsStructuredResponse: Bool
    let enforcesExecutableWork: Bool
    let executesActions: Bool
    let allowsAgenticRetry: Bool

    static let agentic = CoCaptainTurnExecutionPolicy(
        kind: .agentic,
        expectsStructuredResponse: true,
        enforcesExecutableWork: true,
        executesActions: true,
        allowsAgenticRetry: true
    )

    static let advisory = CoCaptainTurnExecutionPolicy(
        kind: .advisory,
        expectsStructuredResponse: true,
        enforcesExecutableWork: false,
        executesActions: true,
        allowsAgenticRetry: false
    )

    static let conversational = CoCaptainTurnExecutionPolicy(
        kind: .conversational,
        expectsStructuredResponse: false,
        enforcesExecutableWork: false,
        executesActions: false,
        allowsAgenticRetry: false
    )
}

/// The terminal outcome of one specific CoCaptain turn.
///
/// The turn purpose lets onboarding react only to the response it initiated,
/// instead of inferring intent from a global response counter.
public struct CoCaptainTurnCompletion: Equatable {
    public let turnID: UUID
    public let purpose: CoCaptainTurnPurpose
    public let succeeded: Bool
    public let presentedReviewBundle: Bool

    public init(
        turnID: UUID,
        purpose: CoCaptainTurnPurpose,
        succeeded: Bool,
        presentedReviewBundle: Bool = false
    ) {
        self.turnID = turnID
        self.purpose = purpose
        self.succeeded = succeeded
        self.presentedReviewBundle = presentedReviewBundle
    }

    var shouldAdvanceToCanvasDismissal: Bool {
        purpose == .onboardingBuildHandoff && succeeded
    }

    var shouldAdvanceToOnboardingReview: Bool {
        purpose == .onboardingGuidedEdit && succeeded && presentedReviewBundle
    }
}

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

/// A short model-authored lesson attached to a node edit proposal.
///
/// Written while the model proposes the edit, but only revealed to the user
/// after they apply it — reinforcing what the change taught them about their
/// own app. Both fields are plain prose aimed at beginners.
public struct CoCaptainLearningNote: Codable, Hashable {
    /// A 2-5 word name for the concept the edit demonstrates.
    public let concept: String
    /// 2-3 plain sentences explaining the concept using the user's own app.
    public let body: String

    public init(concept: String, body: String) {
        self.concept = concept
        self.body = body
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
    /// An optional model-authored lesson revealed after the edit is applied.
    public let learningNote: CoCaptainLearningNote?

    public init(
        nodeID: UUID? = nil,
        role: NodeRole = .miniApp,
        section: MiniAppSection = .code,
        summary: String,
        operations: [NodePatchOperation],
        learningNote: CoCaptainLearningNote? = nil
    ) {
        self.nodeID = nodeID
        self.role = role
        self.section = section
        self.summary = summary
        self.operations = operations
        self.learningNote = learningNote
    }

    private enum CodingKeys: String, CodingKey {
        case nodeID = "nodeId"
        case role
        case section
        case summary
        case operations
        case learningNote
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeID = try container.decodeIfPresent(UUID.self, forKey: .nodeID)
        // Default to .miniApp / .code so the model can omit these fields for the common case.
        self.role = try container.decodeIfPresent(NodeRole.self, forKey: .role) ?? .miniApp
        self.section = try container.decodeIfPresent(MiniAppSection.self, forKey: .section) ?? .code
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.operations = try container.decode([NodePatchOperation].self, forKey: .operations)
        self.learningNote = try container.decodeIfPresent(
            CoCaptainLearningNote.self,
            forKey: .learningNote
        )
    }
}

/// One polite question the assistant asks when a request is too vague to act
/// on. The options render as tappable chips; picking one becomes the user's
/// next message, so no request is ever rejected outright.
public struct CoCaptainClarifyingQuestion: Hashable, Codable {
    public static let minimumOptions = 2
    public static let maximumOptions = 4

    /// The question text, phrased for non-technical users.
    public let prompt: String
    /// Two to four short, concrete answers the user can tap.
    public let options: [String]

    public init(prompt: String, options: [String]) {
        self.prompt = prompt
        self.options = options
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
    /// A structured question the model asks instead of guessing when the
    /// request is ambiguous. Takes precedence over node edits in the same turn.
    public let clarifyingQuestion: CoCaptainClarifyingQuestion?

    public init(
        assistantMessage: String,
        safeActions: [CoCaptainAgentAction] = [],
        pendingActions: [CoCaptainAgentAction] = [],
        nodeEdits: [CoCaptainNodeEditProposal] = [],
        clarifyingQuestion: CoCaptainClarifyingQuestion? = nil
    ) {
        self.assistantMessage = assistantMessage
        self.safeActions = safeActions
        self.pendingActions = pendingActions
        self.nodeEdits = nodeEdits
        self.clarifyingQuestion = clarifyingQuestion
    }
}

/// A wire-format-independent JSON value for function-call arguments.
///
/// Mirrors the shape of `FirebaseAILogic.JSONValue` without importing the SDK
/// into the agent contract, and — unlike the old `[String: String]` argument
/// map — preserves nested objects and arrays so structured tools like
/// `propose_node_edit` can carry operations.
public indirect enum AgentJSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([AgentJSONValue])
    case object([String: AgentJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AgentJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AgentJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// A scalar string rendering: strings pass through, numbers and booleans
    /// are stringified, compound values and null return `nil`.
    public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value == value.rounded() && abs(value) < 1e15
                ? String(Int(value))
                : String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null, .object, .array:
            return nil
        }
    }

    public var arrayValue: [AgentJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    public var objectValue: [String: AgentJSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }
}

extension AgentJSONValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByNilLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(nilLiteral: ()) { self = .null }
    public init(arrayLiteral elements: AgentJSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, AgentJSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

/// Constants for the read-only `read_node_section` tool, answered inline by
/// the coordinator against the active `ProjectStore` during a streaming turn.
public enum CoCaptainReadNodeSectionTool {
    public static let name = "read_node_section"
    /// Cap on the section text returned to the model per call (~30 KB).
    public static let maximumResponseCharacters = 30_000
}

/// Constants for the feature-gated structured node-edit tools that replace
/// the XML `node_edit` / `clarifying_question` contract elements.
public enum CoCaptainNodeEditTools {
    public static let proposeNodeEditName = "propose_node_edit"
    public static let askClarifyingQuestionName = "ask_clarifying_question"
}

/// Answers a model tool call inline during a streaming turn.
///
/// Returns the tool's textual result when the call is a read-style tool the
/// app can execute immediately, or `nil` when the call should instead be
/// collected and routed through the output adapters (e.g. `request_app_action`).
public typealias CoCaptainToolExecutor = @MainActor (CoCaptainAgentFunctionCall) async -> String?

/// A Gemini function-call payload delivered via the streaming API.
///
/// When the model invokes a declared tool (e.g. `request_app_action`), the
/// SDK surfaces it as a function call alongside or instead of text. The
/// composite adapter merges these with any XML-fenced actions.
public struct CoCaptainAgentFunctionCall: Hashable {
    /// The registered tool name as declared in the function declarations schema.
    public let name: String
    /// The arguments the model supplied for this invocation, preserving
    /// nested objects and arrays.
    public let arguments: [String: AgentJSONValue]
    /// An opaque ID assigned by the model; used to deduplicate duplicate
    /// function-call events that can arrive during streaming.
    public let id: String?

    public init(name: String, arguments: [String: AgentJSONValue], id: String? = nil) {
        self.name = name
        self.arguments = arguments
        self.id = id
    }

    /// Returns a trimmed, non-empty scalar argument value for `key`.
    public func stringArgument(_ key: String) -> String? {
        guard let value = arguments[key]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else {
            return nil
        }
        return value
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
public enum ReviewItemStatus: String, Hashable, Codable {
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
    /// The edit target matched several places; the user must pick one of the
    /// item's `clarificationCandidates` before the edit can become pending.
    case needsClarification

    /// A short localized label suitable for display in the review chip.
    public var localizedTitle: String {
        switch self {
        case .pending:
            return LocalizationManager.shared.localizedString("Pending")
        case .applied:
            return LocalizationManager.shared.localizedString("Applied")
        case .conflicted:
            return LocalizationManager.shared.localizedString("Needs another try")
        case .rejected:
            return LocalizationManager.shared.localizedString("Rejected")
        case .needsClarification:
            return LocalizationManager.shared.localizedString("Quick question")
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
public enum PendingReviewSource: Hashable, Codable {
    /// An app-level action (e.g. navigate, open settings) waiting for approval.
    case appAction(AppActionID, [String: String]?)
    /// A proposed node text edit. `baseText` is captured at proposal time so
    /// `NodePatchEngine` can detect intervening changes and flag conflicts.
    case nodeEdit(role: NodeRole, section: CoCaptainNodeEditProposal.MiniAppSection, operations: [NodePatchOperation], baseText: String)
}

/// One actionable change within a `ReviewBundleItem`, representing either a
/// pending app action or a proposed node edit that the user can approve or reject.
public struct PendingReviewItem: Identifiable, Hashable, Codable {
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
    /// Pickable target locations when `status == .needsClarification`.
    /// The user's choice re-stages the edit locally without another model call.
    public var clarificationCandidates: [PatchMatchCandidate]?
    /// A model-authored lesson revealed in the timeline after the user applies
    /// this item. Optional so previously persisted items decode unchanged.
    public var learningNote: CoCaptainLearningNote?

    public init(
        id: UUID = UUID(),
        targetNodeID: UUID? = nil,
        targetLabel: String,
        summary: String,
        preview: String,
        status: ReviewItemStatus = .pending,
        source: PendingReviewSource,
        conflictDescription: String? = nil,
        clarificationCandidates: [PatchMatchCandidate]? = nil,
        learningNote: CoCaptainLearningNote? = nil
    ) {
        self.id = id
        self.targetNodeID = targetNodeID
        self.targetLabel = targetLabel
        self.summary = summary
        self.preview = preview
        self.status = status
        self.source = source
        self.conflictDescription = conflictDescription
        self.clarificationCandidates = clarificationCandidates
        self.learningNote = learningNote
    }
}

/// A named collection of `PendingReviewItem`s produced by a single agent turn.
///
/// The bundle appears as one timeline card with per-item Apply/Reject controls
/// and bulk Apply All / Reject All buttons.
public struct ReviewBundleItem: Identifiable, Hashable, Codable {
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

/// A review bundle persisted on a node so pending approvals survive scope changes.
public struct NodeAgentReviewRecord: Codable, Equatable, Hashable, Identifiable {
    public var id: UUID { timelineItemID }
    public let timelineItemID: UUID
    public var bundle: ReviewBundleItem
    public let createdAt: Date

    public init(timelineItemID: UUID, bundle: ReviewBundleItem, createdAt: Date = Date()) {
        self.timelineItemID = timelineItemID
        self.bundle = bundle
        self.createdAt = createdAt
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
        let source = isUser ? text : ChatBubbleMarkdownNormalizer.normalizeAssistantText(text)
        let fullOptions = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        if let attributed = try? AttributedString(markdown: source, options: fullOptions) {
            return attributed
        }

        let fallbackOptions = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: source, options: fallbackOptions)) ?? AttributedString(source)
    }
}

/// A timeline card presenting a clarifying question with tappable answer
/// options. Once answered, the chosen option is recorded so the card locks.
public struct CoCaptainClarifyingQuestionItem: Identifiable, Hashable {
    public let id: UUID
    public let question: CoCaptainClarifyingQuestion
    /// The option the user tapped, or `nil` while the question is open.
    public var answeredOption: String?

    public init(
        id: UUID = UUID(),
        question: CoCaptainClarifyingQuestion,
        answeredOption: String? = nil
    ) {
        self.id = id
        self.question = question
        self.answeredOption = answeredOption
    }
}

/// A timeline card revealing the lesson behind an applied edit.
///
/// Appears after the execution confirmation once the user taps Apply, so the
/// learning moment lands right when the change becomes real on the canvas.
public struct CoCaptainMentorNoteItem: Identifiable, Hashable {
    public let id: UUID
    public let note: CoCaptainLearningNote

    public init(id: UUID = UUID(), note: CoCaptainLearningNote) {
        self.id = id
        self.note = note
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
    /// A polite question with tappable answer options.
    case clarifyingQuestion(CoCaptainClarifyingQuestionItem)
    /// A "What you just learned" card revealed after an edit is applied.
    case mentorNote(CoCaptainMentorNoteItem)
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
