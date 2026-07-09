import Foundation
import OSLog

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
    ///   - chatMode: Agent vs Ask posture for prompt/context (Ask is prose-only).
    ///   - toolExecutor: Answers read-style tool calls inline during the turn,
    ///     or `nil` when no in-turn tools are available.
    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode,
        toolExecutor: CoCaptainToolExecutor?
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error>
}

public extension CoCaptainLLMClient {
    /// Convenience overload for callers without an in-turn tool executor.
    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        streamAgentEvents(
            for: userMessage,
            context: context,
            expectsStructuredResponse: expectsStructuredResponse,
            availableActions: availableActions,
            scope: scope,
            purpose: purpose,
            chatMode: chatMode,
            toolExecutor: nil
        )
    }
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
    /// A question with tappable answer options to render after the messages,
    /// or `nil` when the assistant did not need to ask anything.
    public let clarifyingQuestion: CoCaptainClarifyingQuestion?

    public init(
        preamble: String,
        payloadMessage: String?,
        executionSummary: ExecutionStatusItem?,
        reviewBundle: ReviewBundleItem?,
        clarifyingQuestion: CoCaptainClarifyingQuestion? = nil
    ) {
        self.preamble = preamble
        self.payloadMessage = payloadMessage
        self.executionSummary = executionSummary
        self.reviewBundle = reviewBundle
        self.clarifyingQuestion = clarifyingQuestion
    }

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
    private let nodeEditToolsEnabled: () -> Bool

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
        validator: CoCaptainAgentValidator = CoCaptainAgentValidator(),
        nodeEditToolsEnabled: (() -> Bool)? = nil
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
        self.nodeEditToolsEnabled = nodeEditToolsEnabled ?? { NodeEditToolsFeature.isEnabled }
    }

    private let logger = Logger(subsystem: "com.caocap.CoCaptainAgentCoordinator", category: "Coordinator")
    private static let maxAgenticRetries = 2

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
        turnPlan: CoCaptainTurnPlan? = nil,
        onVisibleText: @escaping (String) -> Void
    ) async throws -> CoCaptainAgentRunResult {
        let resolvedTurnPlan = turnPlan ?? CoCaptainTurnPlan(purpose: purpose, mode: .agent)
        let contextDetailLevel = resolvedTurnPlan.contextDetailLevel
        let context = store.map { store in
            switch scope {
            case .project:
                return contextBuilder.buildPromptContext(from: store, detailLevel: contextDetailLevel)
            case .node(let nodeID):
                return contextBuilder.buildNodePromptContext(
                    from: store,
                    nodeID: nodeID,
                    detailLevel: contextDetailLevel
                )
            }
        }
        let policy = resolvedTurnPlan.effectivePolicy

        do {
            return try await runOnce(
                userMessage: userMessage,
                context: context,
                expectsStructuredResponse: policy.expectsStructuredResponse,
                store: store,
                dispatcher: dispatcher,
                scope: scope,
                purpose: purpose,
                turnPlan: resolvedTurnPlan,
                onVisibleText: onVisibleText,
                agenticRetriesRemaining: policy.allowsAgenticRetry ? Self.maxAgenticRetries : 0
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard purpose != .onboardingBuildHandoff else { throw error }
            // Fallback: if the structured+context prompt fails (often with opaque
            // `GenerateContentError error 0`), retry with a minimal prompt so chat stays usable.
            let fallbackResult = try await runOnce(
                userMessage: userMessage,
                context: nil,
                expectsStructuredResponse: false,
                store: store,
                dispatcher: dispatcher,
                scope: scope,
                purpose: purpose,
                turnPlan: resolvedTurnPlan,
                onVisibleText: onVisibleText,
                agenticRetriesRemaining: 0,
                connectionFallback: true
            )
            return connectionFallbackResult(
                fallbackResult,
                turnPlan: resolvedTurnPlan
            )
        }
    }

    /// Executes one full LLM round-trip and processes the response.
    ///
    /// - Parameters:
    ///   - agenticRetriesRemaining: How many corrective model retries remain when
    ///     the response fails parsing or validation.
    private func runOnce(
        userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        store: ProjectStore?,
        dispatcher: (any AppActionPerforming)?,
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        turnPlan: CoCaptainTurnPlan,
        onVisibleText: @escaping (String) -> Void,
        agenticRetriesRemaining: Int,
        connectionFallback: Bool = false
    ) async throws -> CoCaptainAgentRunResult {
        let directive = try await generateDirective(
            userMessage: userMessage,
            context: context,
            expectsStructuredResponse: expectsStructuredResponse,
            availableActions: dispatcher?.availableActions ?? [],
            scope: scope,
            purpose: purpose,
            chatMode: turnPlan.mode,
            store: store,
            onVisibleText: onVisibleText
        )
        let policy = turnPlan.effectivePolicy
        let payload = (policy.expectsStructuredResponse || connectionFallback) ? directive.payload : nil

        let requiresAgenticWork = policy.enforcesExecutableWork

        if policy.expectsStructuredResponse {
            if !directive.diagnostics.isEmpty {
                // Invalid structured output: retry with feedback when policy allows.
                if agenticRetriesRemaining > 0 {
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
                        turnPlan: turnPlan,
                        onVisibleText: onVisibleText,
                        agenticRetriesRemaining: agenticRetriesRemaining - 1
                    )
                }

                return validationFailureResult(
                    preamble: directive.preamble,
                    issues: directive.diagnostics
                )
            }

            // Guided-edit (and similar) turns must produce executable work. Agent
            // mode does not: pure chat without an edit is a valid terminal outcome.
            if payload == nil, agenticRetriesRemaining > 0, requiresAgenticWork {
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
                    turnPlan: turnPlan,
                    onVisibleText: onVisibleText,
                    agenticRetriesRemaining: agenticRetriesRemaining - 1
                )
            }

            if let payload {
                let validation = validator.validate(
                    payload: payload,
                    dispatcher: dispatcher,
                    requiresAgenticWork: requiresAgenticWork
                )

                if !validation.isValid {
                    if agenticRetriesRemaining > 0 {
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
                            turnPlan: turnPlan,
                            onVisibleText: onVisibleText,
                            agenticRetriesRemaining: agenticRetriesRemaining - 1
                        )
                    }

                    return validationFailureResult(
                        preamble: directive.preamble,
                        issues: validation.issues
                    )
                }
            }
        } else if connectionFallback, let payload, policy.executesActions {
            let validation = validator.validate(
                payload: payload,
                dispatcher: dispatcher,
                requiresAgenticWork: requiresAgenticWork
            )
            if !validation.isValid {
                return validationFailureResult(
                    preamble: directive.preamble,
                    issues: validation.issues
                )
            }
        }

        if !policy.executesActions {
            return conversationalRunResult(from: directive)
        }

        // A clarifying question takes precedence over any edits in the same
        // turn: the model was unsure, so nothing should be staged until the
        // user answers. Safe/pending actions are also held back.
        if !connectionFallback, let question = payload?.clarifyingQuestion {
            if let payload, !payload.nodeEdits.isEmpty {
                logger.debug("CoCaptain dropped \(payload.nodeEdits.count) node edit(s) accompanying a clarifying question.")
            }
            return CoCaptainAgentRunResult(
                preamble: directive.preamble,
                payloadMessage: payload?.assistantMessage,
                executionSummary: nil,
                reviewBundle: nil,
                clarifyingQuestion: question
            )
        }

        let safeActions = connectionFallback ? [] : (payload?.safeActions ?? [])
        let executionSummary = executeSafeActions(safeActions, dispatcher: dispatcher, store: store)
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

    private func generateDirective(
        userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode,
        store: ProjectStore? = nil,
        onVisibleText: @escaping (String) -> Void
    ) async throws -> CoCaptainAgentDirective {
        var responseText = ""
        var functionCalls: [CoCaptainAgentFunctionCall] = []
        var seenFunctionCallIDs = Set<String>()
        // Ask / conversational turns omit tools and action catalogs so the
        // model cannot be steered into structured edit or app-action work.
        let stream = llmClient.streamAgentEvents(
            for: userMessage,
            context: context,
            expectsStructuredResponse: expectsStructuredResponse,
            availableActions: expectsStructuredResponse ? availableActions : [],
            scope: scope,
            purpose: purpose,
            chatMode: chatMode,
            toolExecutor: expectsStructuredResponse ? makeToolExecutor(store: store) : nil
        )

        for try await event in stream {
            try Task.checkCancellation()
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
        let directive = outputAdapter.directive(from: responseText, functionCalls: functionCalls)
        if directive.payload != nil {
            // Rollout signal: track which wire format delivers structured output
            // so the XML prompt block can be deleted once tool usage dominates.
            logAgentEvent(
                "cocaptain_agent_output_source",
                parameters: ["source": directive.source.rawValue]
            )
        }
        return directive
    }

    /// Builds the in-turn tool executor for read-style tools.
    ///
    /// Only `read_node_section` is answered inline; every other call returns
    /// `nil` so it keeps its existing collect-and-route behavior. Read results
    /// never touch the validator or the review pipeline.
    private func makeToolExecutor(store: ProjectStore?) -> CoCaptainToolExecutor? {
        guard let store else { return nil }
        return { [weak self] functionCall in
            guard let self, functionCall.name == CoCaptainReadNodeSectionTool.name else {
                return nil
            }
            return self.readNodeSection(functionCall: functionCall, store: store)
        }
    }

    /// Resolves one `read_node_section` call against the active store.
    /// Errors are returned as text so the model can self-correct in-turn.
    private func readNodeSection(
        functionCall: CoCaptainAgentFunctionCall,
        store: ProjectStore
    ) -> String {
        let nodeID = (functionCall.stringArgument("nodeId") ?? functionCall.stringArgument("node_id"))
            .flatMap(UUID.init(uuidString:))
        guard let nodeID else {
            return "Error: `read_node_section` requires a valid `nodeId` UUID from the canvas context."
        }
        guard let sectionName = functionCall.stringArgument("section")?.lowercased(),
              let section = CoCaptainNodeEditProposal.MiniAppSection(rawValue: sectionName) else {
            return "Error: `section` must be \"code\" or \"srs\"."
        }
        guard let node = patchEngine.resolveNode(nodeID: nodeID, for: .miniApp, in: store),
              let miniApp = node.miniApp else {
            return "Error: no Mini-App node with id \(nodeID.uuidString) exists on the canvas."
        }

        let text: String
        switch section {
        case .code:
            text = miniApp.codeText
        case .srs:
            text = miniApp.srsText
        }

        logger.debug("read_node_section answered for \(nodeID.uuidString, privacy: .public) section=\(sectionName, privacy: .public) chars=\(text.count, privacy: .public)")
        guard text.count > CoCaptainReadNodeSectionTool.maximumResponseCharacters else {
            return text
        }
        return String(text.prefix(CoCaptainReadNodeSectionTool.maximumResponseCharacters)) + "\n[TRUNCATED]"
    }

    /// A locally-built question offered after a failed turn so the user always
    /// has a tappable next step instead of a dead-end error message.
    private static var recoveryQuestion: CoCaptainClarifyingQuestion {
        CoCaptainClarifyingQuestion(
            prompt: LocalizationManager.shared.localizedString(
                "Want to try one of these instead?"
            ),
            options: [
                LocalizationManager.shared.localizedString("Try that again, please"),
                LocalizationManager.shared.localizedString("Break it into smaller steps"),
                LocalizationManager.shared.localizedString("Suggest what we could do next")
            ]
        )
    }

    private func logAgentEvent(
        _ name: String,
        parameters: [String: String]
    ) {
        AnalyticsService.shared.logEvent(name, parameters: parameters)
    }

    /// Returns visible prose only. Ignores any structured payload the model emitted.
    private func conversationalRunResult(from directive: CoCaptainAgentDirective) -> CoCaptainAgentRunResult {
        CoCaptainAgentRunResult(
            preamble: directive.preamble,
            payloadMessage: nil,
            executionSummary: nil,
            reviewBundle: nil
        )
    }

    /// When the structured prompt fails, annotate the fallback result so users
    /// know executable work may not have been staged.
    private func connectionFallbackResult(
        _ result: CoCaptainAgentRunResult,
        turnPlan: CoCaptainTurnPlan
    ) -> CoCaptainAgentRunResult {
        guard turnPlan.requiresDegradedConnectionNotice,
              result.reviewBundle == nil,
              result.executionSummary == nil else {
            return result
        }

        let notice = LocalizationManager.shared.localizedString(
            "cocaptain.fallback.editsUnavailable"
        )
        let preamble = result.preamble.isEmpty ? notice : "\(result.preamble)\n\n\(notice)"
        return CoCaptainAgentRunResult(
            preamble: preamble,
            payloadMessage: result.payloadMessage,
            executionSummary: result.executionSummary,
            reviewBundle: result.reviewBundle
        )
    }

    /// Builds a corrective system message that feeds validation issues back to
    /// the model along with the original request, giving it a second chance to
    /// produce a conforming structured payload. The wording references the
    /// node-edit tools when they are enabled, the XML block otherwise.
    private func agenticRetryMessage(for userMessage: String, validationIssues: [String]) -> String {
        let issueList = validationIssues.map { "- \($0)" }.joined(separator: "\n")

        if nodeEditToolsEnabled() {
            return """
            The previous response has not satisfied the machine-readable CoCaptain action contract.

            Validation issues:
            \(issueList)
            
            CRITICAL: 
            1. Do NOT just provide code in markdown chat. 
            2. You MUST call the `propose_node_edit` function for code/content changes, or `ask_clarifying_question` when the request is too vague to act on.
            3. For app navigation/tool actions, call `request_app_action`.
            4. Put code/content implementation in `propose_node_edit` operations.
            5. Put mutating or non-autonomous app actions in `request_app_action` with `executionMode=pending`.
            6. Use `executionMode=safe` only for available, non-mutating, autonomous app actions.
            7. For full builds or games, use one `replace_all` operation on the Mini-App `section="code"` with a complete single-file HTML document.
            8. For documentation, requirements, spec, or SRS requests, target the Mini-App `section="srs"` unless the user explicitly asks for code.
            
            Original user request:
            \(userMessage)
            """
        }

        return """
        The previous response has not satisfied the machine-readable CoCaptain action contract.

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

    /// Returns a conversational recovery message when the model response cannot
    /// be executed. Validation details are logged for diagnostics, not shown in UI.
    private func validationFailureResult(
        preamble: String,
        issues: [String]
    ) -> CoCaptainAgentRunResult {
        if !issues.isEmpty {
            logger.debug("CoCaptain validation failure: \(issues.joined(separator: " | "), privacy: .public)")
        }

        let encouragement = LocalizationManager.shared.localizedString(
            "cocaptain.validationFailure.encouragement"
        )

        return CoCaptainAgentRunResult(
            preamble: preamble,
            payloadMessage: encouragement,
            executionSummary: nil,
            reviewBundle: nil,
            clarifyingQuestion: Self.recoveryQuestion
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
                let reason = AppActionID(rawValue: action.actionID) == nil
                    ? LocalizationManager.shared.localizedString(
                        "Unknown pending action id `%@`.",
                        arguments: [action.actionID]
                    )
                    : LocalizationManager.shared.localizedString(
                        "Pending action `%@` is not available in the current context.",
                        arguments: [action.actionID]
                    )
                items.append(
                    PendingReviewItem(
                        targetLabel: action.actionID,
                        summary: LocalizationManager.shared.localizedString(
                            "The assistant proposed an action that could not be staged for review."
                        ),
                        preview: reason,
                        status: .conflicted,
                        source: .nodeEdit(role: .miniApp, section: .srs, operations: [], baseText: "")
                    )
                )
                continue
            }

            items.append(
                PendingReviewItem(
                    targetLabel: definition.localizedTitle,
                    summary: LocalizationManager.shared.localizedString(
                        "Awaiting approval to run %@.",
                        arguments: [definition.localizedTitle]
                    ),
                    preview: actionPreview(for: action, definition: definition),
                    source: .appAction(id, action.args)
                )
            )
        }

        if let store {
            for edit in nodeEdits {
                do {
                    let resolved = try patchEngine.previewResolving(
                        nodeID: edit.nodeID,
                        role: edit.role,
                        section: edit.section,
                        operations: edit.operations,
                        in: store
                    )
                    let preview = resolved.preview
                    let targetNode = store.nodes.first(where: { $0.id == preview.nodeID })
                    let sectionLabel = edit.section.rawValue.uppercased()
                    items.append(
                        PendingReviewItem(
                            targetNodeID: preview.nodeID,
                            targetLabel: "\(targetNode?.displayTitle ?? edit.role.localizedDisplayName) \(sectionLabel)",
                            summary: edit.summary,
                            preview: previewSnippet(for: preview.resultText),
                            source: .nodeEdit(
                                role: edit.role,
                                section: edit.section,
                                operations: resolved.canonicalOperations,
                                baseText: preview.originalText
                            ),
                            learningNote: edit.learningNote ?? Self.fallbackLearningNote(for: edit)
                        )
                    )
                } catch let NodePatchError.ambiguous(_, candidates) {
                    items.append(
                        clarificationReviewItem(for: edit, candidates: candidates, store: store)
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

        return items.isEmpty ? nil : ReviewBundleItem(
            title: reviewBundleTitle(for: items),
            items: items
        )
    }

    /// Builds a review item that asks the user to pick which matched location
    /// an ambiguous edit should target. Captures the node's current section
    /// text as `baseText` so the pick can re-stage deterministically.
    private func clarificationReviewItem(
        for edit: CoCaptainNodeEditProposal,
        candidates: [PatchMatchCandidate],
        store: ProjectStore
    ) -> PendingReviewItem {
        let node = patchEngine.resolveNode(nodeID: edit.nodeID, for: edit.role, in: store)
        let baseText: String
        switch edit.section {
        case .srs:
            baseText = node?.miniApp?.srsText ?? ""
        case .code:
            baseText = node?.miniApp?.codeText ?? ""
        }
        let sectionLabel = edit.section.rawValue.uppercased()

        return PendingReviewItem(
            targetNodeID: node?.id ?? edit.nodeID,
            targetLabel: "\(node?.displayTitle ?? edit.role.localizedDisplayName) \(sectionLabel)",
            summary: edit.summary,
            preview: LocalizationManager.shared.localizedString(
                "I found a few places that could match. Pick the one you meant and I'll make the change."
            ),
            status: .needsClarification,
            source: .nodeEdit(role: edit.role, section: edit.section, operations: edit.operations, baseText: baseText),
            clarificationCandidates: candidates,
            learningNote: edit.learningNote ?? Self.fallbackLearningNote(for: edit)
        )
    }

    /// Builds a locally-authored lesson from the edit summary when the model
    /// omitted a `learning_note`, so the post-apply learning moment never
    /// silently disappears.
    static func fallbackLearningNote(for edit: CoCaptainNodeEditProposal) -> CoCaptainLearningNote? {
        let summary = edit.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { return nil }

        return CoCaptainLearningNote(
            concept: LocalizationManager.shared.localizedString("cocaptain.mentorNote.fallbackConcept"),
            body: LocalizationManager.shared.localizedString(
                "cocaptain.mentorNote.fallbackBody",
                arguments: [summary]
            )
        )
    }

    private func actionPreview(for action: CoCaptainAgentAction, definition: AppActionDefinition) -> String {
        guard let args = action.args, !args.isEmpty else {
            return definition.localizedTitle
        }
        let formattedArgs = args
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        return "\(definition.localizedTitle)\n\(formattedArgs)"
    }

    private func reviewBundleTitle(for items: [PendingReviewItem]) -> String {
        let base = LocalizationManager.shared.localizedString("Pending changes")
        guard items.count > 1 else { return base }
        return LocalizationManager.shared.localizedString(
            "Pending changes (%lld)",
            arguments: [Int64(items.count)]
        )
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
