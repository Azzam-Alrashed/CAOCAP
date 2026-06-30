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
    private let verifier: any MiniAppVerifying
    private let verifiedCodingLoopEnabled: () -> Bool

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
        verifier: (any MiniAppVerifying)? = nil,
        verifiedCodingLoopEnabled: (() -> Bool)? = nil
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
        self.verifier = verifier ?? MiniAppVerificationService()
        self.verifiedCodingLoopEnabled = verifiedCodingLoopEnabled ?? { VerifiedCodingLoopFeature.isEnabled }
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
        onCodingProgress: @escaping (CoCaptainCodingRunState) -> Void = { _ in },
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
        let policy = purpose.executionPolicy

        do {
            return try await runOnce(
                userMessage: userMessage,
                context: context,
                expectsStructuredResponse: policy.expectsStructuredResponse,
                store: store,
                dispatcher: dispatcher,
                scope: scope,
                purpose: purpose,
                onVisibleText: onVisibleText,
                onCodingProgress: onCodingProgress,
                agenticRetriesRemaining: policy.allowsAgenticRetry ? Self.maxAgenticRetries : 0
            )
        } catch is CancellationError {
            onCodingProgress(.cancelled)
            logCodingEvent("cocaptain_coding_loop_cancelled", parameters: ["scope": scope.storageKey])
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
                onVisibleText: onVisibleText,
                onCodingProgress: onCodingProgress,
                agenticRetriesRemaining: 0,
                connectionFallback: true
            )
            return connectionFallbackResult(
                fallbackResult,
                userMessage: userMessage,
                purpose: purpose
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
        onVisibleText: @escaping (String) -> Void,
        onCodingProgress: @escaping (CoCaptainCodingRunState) -> Void,
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
            onVisibleText: onVisibleText
        )
        let policy = purpose.executionPolicy
        let payload = (policy.expectsStructuredResponse || connectionFallback) ? directive.payload : nil

        let requiresAgenticWork =
            policy.enforcesExecutableWork && shouldRequireAgenticWork(for: userMessage)

        if policy.expectsStructuredResponse {
            if !directive.diagnostics.isEmpty {
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
                        onVisibleText: onVisibleText,
                        onCodingProgress: onCodingProgress,
                        agenticRetriesRemaining: agenticRetriesRemaining - 1
                    )
                }

                return validationFailureResult(
                    preamble: directive.preamble,
                    issues: directive.diagnostics
                )
            }

            // Build/edit requests should produce executable work. If the model only
            // chatted back, retry once with a stronger contract before falling back.
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
                    onVisibleText: onVisibleText,
                    onCodingProgress: onCodingProgress,
                    agenticRetriesRemaining: agenticRetriesRemaining - 1
                )
            }

            if let payload {
                let requiresVerification = codingLoopTarget(
                    payload: payload,
                    store: store,
                    purpose: purpose
                ) != nil
                let validation = validator.validate(
                    payload: payload,
                    dispatcher: dispatcher,
                    requiresAgenticWork: requiresAgenticWork,
                    requiresVerificationChecks: requiresVerification
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
                            onVisibleText: onVisibleText,
                            onCodingProgress: onCodingProgress,
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
                requiresAgenticWork: requiresAgenticWork,
                requiresVerificationChecks: false
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

        if !connectionFallback,
           let payload,
           let target = codingLoopTarget(payload: payload, store: store, purpose: purpose) {
            do {
                return try await runVerifiedCodingLoop(
                    originalRequest: userMessage,
                    initialDirective: directive,
                    initialPayload: payload,
                    target: target,
                    dispatcher: dispatcher,
                    scope: scope,
                    purpose: purpose,
                    onCodingProgress: onCodingProgress
                )
            } catch is CancellationError {
                onCodingProgress(.cancelled)
                throw CancellationError()
            } catch {
                let message = error.localizedDescription
                onCodingProgress(.failed(message))
                return codingLoopFailureResult(
                    preamble: directive.preamble,
                    message: message
                )
            }
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
        onVisibleText: @escaping (String) -> Void
    ) async throws -> CoCaptainAgentDirective {
        var responseText = ""
        var functionCalls: [CoCaptainAgentFunctionCall] = []
        var seenFunctionCallIDs = Set<String>()
        let stream = llmClient.streamAgentEvents(
            for: userMessage,
            context: context,
            expectsStructuredResponse: expectsStructuredResponse,
            availableActions: availableActions,
            scope: scope,
            purpose: purpose
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
        return outputAdapter.directive(from: responseText, functionCalls: functionCalls)
    }

    private struct CodingLoopTarget {
        let node: SpatialNode
        let edit: CoCaptainNodeEditProposal
        let baseCode: String
        let store: ProjectStore
    }

    private func codingLoopTarget(
        payload: CoCaptainAgentPayload,
        store: ProjectStore?,
        purpose: CoCaptainTurnPurpose
    ) -> CodingLoopTarget? {
        guard verifiedCodingLoopEnabled(),
              purpose == .standard,
              let store,
              payload.nodeEdits.count == 1,
              let edit = payload.nodeEdits.first,
              edit.section == .code,
              let node = patchEngine.resolveNode(nodeID: edit.nodeID, for: edit.role, in: store) else {
            return nil
        }

        let baseCode = node.miniApp?.codeText ?? ""
        let trimmedBase = baseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBase.isEmpty {
            guard edit.operations.count == 1,
                  edit.operations.first?.type == .replaceAll,
                  !edit.verificationChecks.isEmpty else {
                return nil
            }
        }

        return CodingLoopTarget(node: node, edit: edit, baseCode: baseCode, store: store)
    }

    private func runVerifiedCodingLoop(
        originalRequest: String,
        initialDirective: CoCaptainAgentDirective,
        initialPayload: CoCaptainAgentPayload,
        target: CodingLoopTarget,
        dispatcher: (any AppActionPerforming)?,
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        onCodingProgress: @escaping (CoCaptainCodingRunState) -> Void
    ) async throws -> CoCaptainAgentRunResult {
        let startedAt = Date()
        onCodingProgress(.planning)
        logCodingEvent("cocaptain_coding_loop_started", parameters: ["scope": scope.storageKey])

        if let reason = verifier.unsupportedReason(for: target.node) {
            onCodingProgress(.failed(reason))
            logCodingCompletion(startedAt: startedAt, attempts: 0, outcome: "unsupported")
            return codingLoopFailureResult(preamble: initialDirective.preamble, message: reason)
        }

        var attempt = 1
        var currentCode = target.baseCode
        var candidateEdit = target.edit
        var candidateChecks = candidateEdit.verificationChecks
        var candidateMessage = initialPayload.assistantMessage
        var lastFeedback = ""

        while attempt <= 3 {
            try Task.checkCancellation()
            onCodingProgress(.building(attempt: attempt))

            do {
                currentCode = try patchEngine.apply(
                    operations: candidateEdit.operations,
                    to: attempt == 1 ? target.baseCode : currentCode
                )
            } catch {
                lastFeedback = "- invalidCandidate: \(error.localizedDescription)"
                if attempt == 3 { break }
                attempt += 1
                onCodingProgress(.repairing(nextAttempt: attempt))
                let repair = try await generateRepairCandidate(
                    originalRequest: originalRequest,
                    currentCode: currentCode,
                    feedback: lastFeedback,
                    targetNodeID: target.node.id,
                    dispatcher: dispatcher,
                    scope: scope,
                    purpose: purpose
                )
                candidateEdit = repair.edit
                candidateChecks = repair.edit.verificationChecks
                candidateMessage = repair.message
                continue
            }

            onCodingProgress(.testing(attempt: attempt))
            let verification = await verifier.verify(
                code: currentCode,
                checks: candidateChecks,
                node: target.node
            )
            try Task.checkCancellation()
            logCodingEvent(
                "cocaptain_coding_loop_attempt",
                parameters: [
                    "attempt": String(attempt),
                    "outcome": verification.passed ? "passed" : "failed"
                ]
            )

            if verification.passed {
                let finalEdit = CoCaptainNodeEditProposal(
                    nodeID: target.node.id,
                    role: candidateEdit.role,
                    section: .code,
                    summary: candidateEdit.summary,
                    operations: [
                        NodePatchOperation(type: .replaceAll, content: currentCode)
                    ],
                    verificationChecks: candidateChecks
                )
                let finalPayload = CoCaptainAgentPayload(
                    assistantMessage: mentorSummary(
                        candidateMessage,
                        checks: candidateChecks,
                        attempts: attempt
                    ),
                    safeActions: initialPayload.safeActions,
                    pendingActions: initialPayload.pendingActions,
                    nodeEdits: [finalEdit]
                )
                onCodingProgress(.readyForReview(attempts: attempt))
                logCodingCompletion(startedAt: startedAt, attempts: attempt, outcome: "verified")
                let executionSummary = executeSafeActions(
                    finalPayload.safeActions,
                    dispatcher: dispatcher,
                    store: target.store
                )
                let reviewBundle = buildReviewBundle(
                    pendingActions: finalPayload.pendingActions,
                    nodeEdits: finalPayload.nodeEdits,
                    store: target.store,
                    dispatcher: dispatcher
                )
                return CoCaptainAgentRunResult(
                    preamble: initialDirective.preamble,
                    payloadMessage: finalPayload.assistantMessage,
                    executionSummary: executionSummary,
                    reviewBundle: reviewBundle
                )
            }

            lastFeedback = verification.compactFeedback
            if attempt == 3 { break }
            attempt += 1
            onCodingProgress(.repairing(nextAttempt: attempt))
            let repair = try await generateRepairCandidate(
                originalRequest: originalRequest,
                currentCode: currentCode,
                feedback: lastFeedback,
                targetNodeID: target.node.id,
                dispatcher: dispatcher,
                scope: scope,
                purpose: purpose
            )
            candidateEdit = repair.edit
            candidateChecks = repair.edit.verificationChecks
            candidateMessage = repair.message
        }

        let message = lastFeedback.isEmpty
            ? "CoCaptain could not produce a verified change."
            : "No verified change is ready. \(lastFeedback)"
        onCodingProgress(.failed(message))
        logCodingCompletion(startedAt: startedAt, attempts: attempt, outcome: "failed")
        return codingLoopFailureResult(preamble: initialDirective.preamble, message: message)
    }

    private func generateRepairCandidate(
        originalRequest: String,
        currentCode: String,
        feedback: String,
        targetNodeID: UUID,
        dispatcher: (any AppActionPerforming)?,
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose
    ) async throws -> (edit: CoCaptainNodeEditProposal, message: String) {
        let prompt = """
        Repair the staged Mini-App candidate using the verification feedback below.
        Return exactly one code node_edit targeting nodeId="\(targetNodeID.uuidString)".
        Operations apply to the current staged code, not the original canvas code.
        Include 1 to 5 verification_check entries. Do not request app actions.

        Original request:
        \(originalRequest)

        Verification feedback:
        \(feedback)

        Current staged code:
        \(currentCode)
        """
        let directive = try await generateDirective(
            userMessage: prompt,
            context: nil,
            expectsStructuredResponse: true,
            availableActions: [],
            scope: scope,
            purpose: purpose,
            onVisibleText: { _ in }
        )
        guard directive.diagnostics.isEmpty,
              let payload = directive.payload,
              payload.nodeEdits.count == 1,
              let edit = payload.nodeEdits.first,
              edit.section == .code,
              edit.nodeID == nil || edit.nodeID == targetNodeID else {
            throw CodingLoopError.invalidRepair
        }
        let validation = validator.validate(
            payload: payload,
            dispatcher: dispatcher,
            requiresAgenticWork: true,
            requiresVerificationChecks: true
        )
        guard validation.isValid else {
            throw CodingLoopError.invalidRepair
        }
        return (edit, payload.assistantMessage)
    }

    private enum CodingLoopError: LocalizedError {
        case invalidRepair

        var errorDescription: String? {
            "The repair response did not contain one valid, verifiable code edit."
        }
    }

    private func mentorSummary(
        _ modelMessage: String,
        checks: [CoCaptainVerificationCheck],
        attempts: Int
    ) -> String {
        let descriptions = checks.map(\.description).joined(separator: ", ")
        let prefix = modelMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let verification = "Verified in \(attempts) attempt(s): \(descriptions)."
        let concept = "Concept: staged execution tests a proposed change before it touches your canvas."
        return [prefix, verification, concept].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private func codingLoopFailureResult(
        preamble: String,
        message: String
    ) -> CoCaptainAgentRunResult {
        CoCaptainAgentRunResult(
            preamble: preamble,
            payloadMessage: message,
            executionSummary: nil,
            reviewBundle: nil
        )
    }

    private func logCodingCompletion(
        startedAt: Date,
        attempts: Int,
        outcome: String
    ) {
        logCodingEvent(
            "cocaptain_coding_loop_completed",
            parameters: [
                "attempts": String(attempts),
                "duration_ms": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
                "outcome": outcome,
                "model_backend": UserDefaults.standard.string(forKey: "cocaptain.modelName") == "gemma-4-local"
                    ? "local"
                    : "firebase"
            ]
        )
    }

    private func logCodingEvent(
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

    /// Returns `true` when the user's message contains a keyword that implies
    /// the model should produce executable output (actions or node edits).
    ///
    /// Used to decide whether a chat-only model response is treated as a
    /// contract violation that warrants an agentic retry.
    private func shouldRequireAgenticWork(for userMessage: String) -> Bool {
        let normalized = CommandIntentResolver.normalizedCommandInput(userMessage)
        guard !CommandIntentResolver.hasNegation(in: normalized) else { return false }

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
            "navigate",
            "settings",
            "root",
            "انشاء",
            "اضف",
            "أضف",
            "عدل",
            "غير",
            "حدث",
            "اصلح",
            "اكتب",
            "وثق",
            "افتح",
            "اذهب",
            "اعرض",
            "الاعدادات",
            "الإعدادات"
        ]

        return triggers.contains { normalized.contains($0) }
    }

    /// Builds a corrective system message that feeds validation issues back to
    /// the model along with the original request, giving it a second chance to
    /// produce a conforming `cocaptain_actions` XML block.
    private func agenticRetryMessage(for userMessage: String, validationIssues: [String]) -> String {
        let issueList = validationIssues.map { "- \($0)" }.joined(separator: "\n")

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
        9. For an existing Mini-App code edit, include 1 to 5 `verification_check` entries with unique ids, descriptions, and CDATA-wrapped JavaScript that returns true only when the requested behavior works.
        
        Original user request:
        \(userMessage)
        """
    }

    /// When the structured prompt fails, annotate the fallback result so users
    /// know executable work may not have been staged.
    private func connectionFallbackResult(
        _ result: CoCaptainAgentRunResult,
        userMessage: String,
        purpose: CoCaptainTurnPurpose
    ) -> CoCaptainAgentRunResult {
        guard purpose.executionPolicy.enforcesExecutableWork,
              shouldRequireAgenticWork(for: userMessage),
              result.reviewBundle == nil,
              result.executionSummary == nil else {
            return result
        }

        let notice = LocalizationManager.shared.localizedString(
            "CoCaptain could not reach the model with full project context. Your request was answered in chat only — actions and edits were not applied. Try again when connected."
        )
        let preamble = result.preamble.isEmpty ? notice : "\(result.preamble)\n\n\(notice)"
        return CoCaptainAgentRunResult(
            preamble: preamble,
            payloadMessage: result.payloadMessage,
            executionSummary: result.executionSummary,
            reviewBundle: result.reviewBundle
        )
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
            reviewBundle: nil
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

        return items.isEmpty ? nil : ReviewBundleItem(
            title: reviewBundleTitle(for: items),
            items: items
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
