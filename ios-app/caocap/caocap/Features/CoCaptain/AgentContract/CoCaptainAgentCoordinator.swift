import Foundation

/// The interface through which `CoCaptainAgentCoordinator` communicates with
/// the underlying language model.
///
/// Abstracting the LLM behind this protocol allows unit tests to inject a
/// lightweight stub without touching `LLMService` or Firebase AI Logic.
@MainActor
public protocol CoCaptainLLMClient: AnyObject {
    /// Clears the model's conversation history for the given scope, starting a
    /// fresh chat session. Called when the user taps "Clear" in the chat UI.
    func resetChat(scope: CoCaptainAgentScope)
    /// Streams incremental model output for one user turn.
    ///
    /// - Parameters:
    ///   - userMessage: The raw text entered by the user.
    ///   - context: A serialised snapshot of the active canvas, or `nil` when
    ///     running in reduced / fallback mode.
    ///   - expectsStructuredResponse: When `true` the system prompt instructs the
    ///     model to wrap executable output in a `cocaptain_actions` XML block.
    ///   - availableActions: The set of `AppActionDefinition`s the model may call
    ///     via `request_app_action`. Sent as tool declarations in each turn.
    ///   - scope: Whether this turn targets the whole project or a single node.
    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error>
}

extension LLMService: CoCaptainLLMClient {}

/// The complete result of one CoCaptain assistant turn, ready for the view
/// model to splice into the conversation timeline.
public struct CoCaptainAgentRunResult: Hashable {
    /// The text that appeared before the structured `cocaptain_actions` block,
    /// i.e. the model's conversational prose.
    public let preamble: String
    /// The chat text extracted from inside the structured payload, if present.
    public let payloadMessage: String?
    /// A confirmation item to append when one or more safe actions were executed.
    public let executionSummary: ExecutionStatusItem?
    /// A set of node edits or pending actions the user must review before they
    /// take effect, or `nil` when the model produced no reviewable changes.
    public let reviewBundle: ReviewBundleItem?

    /// The text the chat bubble should display.
    ///
    /// Prefers the preamble because it is the richer, prose form. Falls back to
    /// `payloadMessage` when the model placed all its text inside the XML block.
    public var visibleText: String {
        if preamble.isEmpty { return payloadMessage ?? "" }
        return preamble
    }
}

/// Bridges model output to app behavior while keeping mutating code edits in
/// an explicit review flow.
@MainActor
public final class CoCaptainAgentCoordinator {
    private let llmClient: any CoCaptainLLMClient
    private let contextBuilder: ProjectContextBuilder
    private let patchEngine: NodePatchEngine
    private let outputAdapter: any CoCaptainAgentOutputAdapting
    private let validator: CoCaptainAgentValidator

    /// Creates a coordinator with optional dependency overrides for testing.
    ///
    /// All parameters have sensible production defaults; only supply non-nil
    /// values when you need to inject stubs or alternative implementations.
    public init(
        llmClient: (any CoCaptainLLMClient)? = nil,
        contextBuilder: ProjectContextBuilder = ProjectContextBuilder(),
        patchEngine: NodePatchEngine = NodePatchEngine(),
        parser: CoCaptainAgentParser = CoCaptainAgentParser(),
        outputAdapter: (any CoCaptainAgentOutputAdapting)? = nil,
        validator: CoCaptainAgentValidator = CoCaptainAgentValidator()
    ) {
        self.llmClient = llmClient ?? LLMService.shared
        self.contextBuilder = contextBuilder
        self.patchEngine = patchEngine
        // Wrap the XML adapter in the composite so function-call responses are
        // merged with fenced-XML responses when both arrive in the same turn.
        self.outputAdapter = outputAdapter ?? CoCaptainCompositeAgentAdapter(
            xmlAdapter: CoCaptainXMLAgentAdapter(parser: parser)
        )
        self.validator = validator
    }

    /// Resets the chat history for the given scope, forwarding directly to the
    /// LLM client. Defaults to the project scope for callers that don't track scope.
    public func resetChat(scope: CoCaptainAgentScope = .project) {
        llmClient.resetChat(scope: scope)
    }

    /// Runs one assistant turn against the active project context. Structured
    /// responses are preferred so the UI can separate visible chat text from
    /// executable actions and reviewable node edits.
    public func run(
        userMessage: String,
        store: ProjectStore?,
        dispatcher: (any AppActionPerforming)?,
        scope: CoCaptainAgentScope = .project,
        purpose: CoCaptainTurnPurpose = .standard,
        onVisibleText: @escaping (String) -> Void
    ) async throws -> CoCaptainAgentRunResult {
        let context = store.map { store in
            switch scope {
            case .project:
                return contextBuilder.buildPromptContext(from: store)
            case .node(let nodeID):
                return contextBuilder.buildNodePromptContext(from: store, nodeID: nodeID)
            }
        }
        do {
            return try await runOnce(
                userMessage: userMessage,
                context: context,
                expectsStructuredResponse: true,
                store: store,
                dispatcher: dispatcher,
                scope: scope,
                purpose: purpose,
                onVisibleText: onVisibleText,
                allowAgenticRetry: true
            )
        } catch {
            // Fallback: if the structured+context prompt fails (often with opaque
            // `GenerateContentError error 0`), retry with a minimal prompt so chat stays usable.
            return try await runOnce(
                userMessage: userMessage,
                context: nil,
                expectsStructuredResponse: false,
                store: store,
                dispatcher: dispatcher,
                scope: scope,
                purpose: purpose,
                onVisibleText: onVisibleText,
                allowAgenticRetry: false
            )
        }
    }

    /// Executes one full LLM round-trip and processes the response.
    ///
    /// - Parameters:
    ///   - allowAgenticRetry: When `true` the method may recursively call itself
    ///     once with a corrective system message if the model's output fails
    ///     validation. The recursive call always passes `false` to prevent loops.
    private func runOnce(
        userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        store: ProjectStore?,
        dispatcher: (any AppActionPerforming)?,
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        onVisibleText: @escaping (String) -> Void,
        allowAgenticRetry: Bool
    ) async throws -> CoCaptainAgentRunResult {
        var responseText = ""
        var functionCalls: [CoCaptainAgentFunctionCall] = []
        var seenFunctionCallIDs = Set<String>()

        let stream = llmClient.streamAgentEvents(
            for: userMessage,
            context: context,
            expectsStructuredResponse: expectsStructuredResponse,
            availableActions: dispatcher?.availableActions ?? [],
            scope: scope,
            purpose: purpose
        )

        for try await event in stream {
            switch event {
            case .text(let chunk):
                responseText += chunk
                onVisibleText(outputAdapter.visibleText(from: responseText))
            case .functionCalls(let calls):
                for call in calls where shouldAppend(functionCall: call, seenIDs: &seenFunctionCallIDs) {
                    functionCalls.append(call)
                }
            }
        }

        // The visible chat can stream before the structured block is complete;
        // only parse actions after the model has finished the turn.
        let directive = outputAdapter.directive(from: responseText, functionCalls: functionCalls)
        let payload = expectsStructuredResponse ? directive.payload : nil

        let requiresAgenticWork = shouldRequireAgenticWork(for: userMessage)

        if expectsStructuredResponse {
            if !directive.diagnostics.isEmpty {
                if allowAgenticRetry {
                    return try await runOnce(
                        userMessage: agenticRetryMessage(
                            for: userMessage,
                            validationIssues: directive.diagnostics
                        ),
                        context: context,
                        expectsStructuredResponse: true,
                        store: store,
                        dispatcher: dispatcher,
                        scope: scope,
                        purpose: purpose,
                        onVisibleText: onVisibleText,
                        allowAgenticRetry: false
                    )
                }

                return CoCaptainAgentRunResult(
                    preamble: directive.preamble,
                    payloadMessage: nil,
                    executionSummary: nil,
                    reviewBundle: validationReviewBundle(issues: directive.diagnostics)
                )
            }

            // Build/edit requests should produce executable work. If the model only
            // chatted back, retry once with a stronger contract before falling back.
            if payload == nil, allowAgenticRetry, requiresAgenticWork {
                return try await runOnce(
                    userMessage: agenticRetryMessage(
                        for: userMessage,
                        validationIssues: directive.diagnostics.isEmpty
                            ? ["Missing machine-readable CoCaptain action directive."]
                            : directive.diagnostics
                    ),
                    context: context,
                    expectsStructuredResponse: true,
                    store: store,
                    dispatcher: dispatcher,
                    scope: scope,
                    purpose: purpose,
                    onVisibleText: onVisibleText,
                    allowAgenticRetry: false
                )
            }

            if let payload {
                let validation = validator.validate(
                    payload: payload,
                    dispatcher: dispatcher,
                    requiresAgenticWork: requiresAgenticWork
                )

                if !validation.isValid {
                    if allowAgenticRetry {
                        return try await runOnce(
                            userMessage: agenticRetryMessage(
                                for: userMessage,
                                validationIssues: validation.issues
                            ),
                            context: context,
                            expectsStructuredResponse: true,
                            store: store,
                            dispatcher: dispatcher,
                            scope: scope,
                            purpose: purpose,
                            onVisibleText: onVisibleText,
                            allowAgenticRetry: false
                        )
                    }

                    return CoCaptainAgentRunResult(
                        preamble: directive.preamble,
                        payloadMessage: payload.assistantMessage,
                        executionSummary: nil,
                        reviewBundle: validationReviewBundle(issues: validation.issues)
                    )
                }
            }
        }

        let executionSummary = executeSafeActions(payload?.safeActions ?? [], dispatcher: dispatcher, store: store)
        let reviewBundle = buildReviewBundle(
            pendingActions: payload?.pendingActions ?? [],
            nodeEdits: payload?.nodeEdits ?? [],
            store: store,
            dispatcher: dispatcher
        )

        return CoCaptainAgentRunResult(
            preamble: directive.preamble,
            payloadMessage: payload?.assistantMessage,
            executionSummary: executionSummary,
            reviewBundle: reviewBundle
        )
    }

    /// Returns `true` when the user's message contains a keyword that implies
    /// the model should produce executable output (actions or node edits).
    ///
    /// Used to decide whether a chat-only model response is treated as a
    /// contract violation that warrants an agentic retry.
    private func shouldRequireAgenticWork(for userMessage: String) -> Bool {
        let lowercased = userMessage.lowercased()
        let triggers = [
            "build",
            "make",
            "create",
            "add",
            "change",
            "update",
            "fix",
            "remove",
            "style",
            "implement",
            "improve",
            "document",
            "write",
            "rewrite",
            "draft",
            "open",
            "go",
            "show",
            "navigate",
            "settings",
            "root"
        ]

        return triggers.contains { lowercased.contains($0) }
    }

    /// Builds a corrective system message that feeds validation issues back to
    /// the model along with the original request, giving it a second chance to
    /// produce a conforming `cocaptain_actions` XML block.
    private func agenticRetryMessage(for userMessage: String, validationIssues: [String]) -> String {
        let issueList = validationIssues.map { "- \($0)" }.joined(separator: "\n")

        return """
        The previous response did not satisfy the machine-readable CoCaptain action contract.

        Validation issues:
        \(issueList)
        
        CRITICAL: 
        1. Do NOT just provide code in markdown chat. 
        2. You MUST include a `cocaptain_actions` XML block.
        3. For app navigation/tool actions, call `request_app_action`.
        4. Put code/content implementation in `nodeEdits`.
        5. Put mutating or non-autonomous app actions in `pendingActions` or call `request_app_action` with `executionMode=pending`.
        6. Use `safeActions` or `executionMode=safe` only for available, non-mutating, autonomous app actions.
        7. For full builds or games, use `replace_all` for the Mini-App `section="code"` with a complete single-file HTML document.
        8. For documentation, requirements, spec, or SRS requests, target the Mini-App `section="srs"` unless the user explicitly asks for code.
        
        Original user request:
        \(userMessage)
        """
    }

    /// Guards against duplicate function-call events that can be emitted by the
    /// streaming SDK when a turn is retried or partially flushed.
    ///
    /// Function calls without an `id` are always accepted because they cannot
    /// be reliably deduplicated.
    private func shouldAppend(
        functionCall: CoCaptainAgentFunctionCall,
        seenIDs: inout Set<String>
    ) -> Bool {
        guard let id = functionCall.id else { return true }
        return seenIDs.insert(id).inserted
    }

    /// Wraps a list of validation issue strings into a conflicted `ReviewBundleItem`
    /// so the user can see *why* the model's response was rejected rather than
    /// receiving a silent failure or a confusing empty chat bubble.
    private func validationReviewBundle(issues: [String]) -> ReviewBundleItem {
        ReviewBundleItem(
            title: LocalizationManager.shared.localizedString("CoCaptain action needs revision"),
            items: [
                PendingReviewItem(
                    targetLabel: LocalizationManager.shared.localizedString("CoCaptain action contract"),
                    summary: LocalizationManager.shared.localizedString("The assistant response could not be executed safely."),
                    preview: issues.joined(separator: "\n"),
                    status: .conflicted,
                    source: .nodeEdit(role: .miniApp, section: .srs, operations: [], baseText: "")
                )
            ]
        )
    }

    /// Executes all safe (autonomous) actions immediately and returns a
    /// summary item to display in the timeline.
    ///
    /// A store checkpoint is created before execution so the user can revert
    /// a batch of automatic changes in one step if needed.
    private func executeSafeActions(
        _ actions: [CoCaptainAgentAction],
        dispatcher: (any AppActionPerforming)?,
        store: ProjectStore?
    ) -> ExecutionStatusItem? {
        guard let dispatcher, !actions.isEmpty else { return nil }

        // Create a checkpoint before executing multiple safe actions to allow revert
        store?.createAutoCheckpoint(label: "Before AI Actions")

        let executedSummaries = actions.compactMap { action -> String? in
            guard let id = AppActionID(rawValue: action.actionID) else { return nil }
            let result = dispatcher.perform(id, source: .agentAutomatic, arguments: action.args)
            return result.executed ? result.title : nil
        }

        guard !executedSummaries.isEmpty else { return nil }
        return ExecutionStatusItem(
            summary: LocalizationManager.shared.localizedString(
                "agent.executedSummary",
                arguments: [executedSummaries.joined(separator: ", ")]
            )
        )
    }

    /// Converts pending actions and node edits into review items. Node edit
    /// previews capture the current text as `baseText` so apply can detect
    /// whether the user changed the node after the model response.
    private func buildReviewBundle(
        pendingActions: [CoCaptainAgentAction],
        nodeEdits: [CoCaptainNodeEditProposal],
        store: ProjectStore?,
        dispatcher: (any AppActionPerforming)?
    ) -> ReviewBundleItem? {
        var items: [PendingReviewItem] = []

        for action in pendingActions {
            guard let id = AppActionID(rawValue: action.actionID),
                  let definition = dispatcher?.definition(for: id) else {
                continue
            }

            items.append(
                PendingReviewItem(
                    targetLabel: definition.localizedTitle,
                    summary: LocalizationManager.shared.localizedString(
                        "Awaiting approval to run %@.",
                        arguments: [definition.localizedTitle]
                    ),
                    preview: action.args?.description ?? definition.localizedTitle,
                    source: .appAction(id, action.args)
                )
            )
        }

        if let store {
            for edit in nodeEdits {
                do {
                    let preview = try patchEngine.preview(nodeID: edit.nodeID, role: edit.role, section: edit.section, operations: edit.operations, in: store)
                    let targetNode = store.nodes.first(where: { $0.id == preview.nodeID })
                    let sectionLabel = edit.section.rawValue.uppercased()
                    items.append(
                        PendingReviewItem(
                            targetNodeID: preview.nodeID,
                            targetLabel: "\(targetNode?.displayTitle ?? edit.role.localizedDisplayName) \(sectionLabel)",
                            summary: edit.summary,
                            preview: previewSnippet(for: preview.resultText),
                            source: .nodeEdit(role: edit.role, section: edit.section, operations: edit.operations, baseText: preview.originalText)
                        )
                    )
                } catch {
                    items.append(
                        PendingReviewItem(
                            targetNodeID: edit.nodeID,
                            targetLabel: edit.role.localizedDisplayName,
                            summary: edit.summary,
                            preview: error.localizedDescription,
                            status: .conflicted,
                            source: .nodeEdit(role: edit.role, section: edit.section, operations: edit.operations, baseText: "")
                        )
                    )
                }
            }
        } else {
            for edit in nodeEdits {
                items.append(
                    PendingReviewItem(
                        targetNodeID: edit.nodeID,
                        targetLabel: edit.role.localizedDisplayName,
                        summary: edit.summary,
                        preview: LocalizationManager.shared.localizedString("No active project context is available for this edit."),
                        status: .conflicted,
                        source: .nodeEdit(role: edit.role, section: edit.section, operations: edit.operations, baseText: "")
                    )
                )
            }
        }

        return items.isEmpty ? nil : ReviewBundleItem(items: items)
    }

    /// Trims whitespace and caps the preview at 280 characters to keep the
    /// review card compact. The `[TRUNCATED]` suffix signals that additional
    /// content exists in the full node text.
    private func previewSnippet(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 280 else { return trimmed }
        return String(trimmed.prefix(280)) + "\n[TRUNCATED]"
    }
}
