import Observation
import SwiftUI

@MainActor
@Observable
public final class CoCaptainViewModel {
    public var isPresented: Bool = false
    public var items: [CoCaptainTimelineItem]
    public private(set) var scope: CoCaptainAgentScope = .project
    public private(set) var focusedNodeID: UUID?
    public var store: ProjectStore? {
        didSet {
            handleStoreChange()
        }
    }
    public var analysisItems: [ProjectSuggestion] = []
    
    @ObservationIgnored
    private let analyzer = ProjectAnalyzer()
    @ObservationIgnored
    public var actionDispatcher: (any AppActionPerforming)? {
        didSet {
            bindReviewSessionIfNeeded()
        }
    }

    /// Tracks the ID of the message that was last visible to the user.
    public var lastScrollPosition: UUID?
    /// One-shot scroll target for actions like "Show Pending Reviews".
    public var scrollFocusRequest: UUID?
    /// When true, the timeline should follow new content to the bottom once.
    public var shouldPinToBottom = false

    @ObservationIgnored
    private let agentCoordinator: CoCaptainAgentCoordinator
    @ObservationIgnored
    private let commandIntentResolver = CommandIntentResolver()
    @ObservationIgnored
    private let reviewLifecycle: CoCaptainReviewLifecycle
    @ObservationIgnored
    private var reviewSession: CoCaptainReviewLifecycle.Session?
    @ObservationIgnored
    private var reviewSessionScope: CoCaptainAgentScope?
    @ObservationIgnored
    private var reviewSessionStoreID: ObjectIdentifier?
    @ObservationIgnored
    private var reviewSessionDispatcherID: ObjectIdentifier?
    @ObservationIgnored
    private var lastStoreID: ObjectIdentifier?
    @ObservationIgnored
    private var streamingTask: Task<Void, Never>?

    /// Called when the user asks to fly the canvas to a review target node.
    @ObservationIgnored
    public var onFlyToNode: ((UUID) -> Void)?

    public var isThinking: Bool = false
    /// Selected CoCaptain chat mode. Defaults to Agent; composer persists via `CoCaptainChatMode.storageKey`.
    public var chatMode: CoCaptainChatMode = .agent
    /// The cumulative number of completed assistant turns/responses. This increments whenever a model
    /// streaming task, execution result, or local command finishes. Used to synchronize onboarding prompts.
    public private(set) var completedAssistantResponseCount: Int = 0
    /// The cumulative number of assistant turns that produced a usable response.
    /// Errors remain completed turns but do not advance this counter.
    public private(set) var successfulAssistantResponseCount: Int = 0
    /// The most recent terminal outcome, including the purpose of the exact turn
    /// that completed. Onboarding observes this instead of global counters.
    public var onReviewItemApplied: ((UUID, UUID) -> Void)?
    public var onOnboardingReviewFallback: (() -> Void)?

    public private(set) var lastTurnCompletion: CoCaptainTurnCompletion?
    public var isAwaitingFirstResponse: Bool {
        guard isThinking,
              let lastMessage,
              !lastMessage.isUser else {
            return false
        }
        return lastMessage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Count of review items still awaiting user approval in the current timeline.
    public var pendingReviewCount: Int {
        items.reduce(into: 0) { count, item in
            guard case .reviewBundle(let bundle) = item.content else { return }
            count += bundle.items.filter { $0.status.isUnresolved }.count
        }
    }

    /// Timeline item ID for the first bundle that still has pending review items.
    public var firstPendingReviewBundleID: UUID? {
        items.first { item in
            guard case .reviewBundle(let bundle) = item.content else { return false }
            return bundle.items.contains { $0.status.isUnresolved }
        }?.id
    }

    public func focusPendingReviews() {
        scrollFocusRequest = firstPendingReviewBundleID
    }

    /// ID of the last rendered timeline row, used to detect whether the user is at the bottom.
    public var bottomTimelineItemID: UUID? {
        items.last(where: { !$0.isEmptyAssistantMessage })?.id
    }

    public func requestScrollToBottom() {
        shouldPinToBottom = true
    }

    public init(
        agentCoordinator: CoCaptainAgentCoordinator? = nil,
        reviewLifecycle: CoCaptainReviewLifecycle? = nil
    ) {
        self.agentCoordinator = agentCoordinator ?? CoCaptainAgentCoordinator()
        self.reviewLifecycle = reviewLifecycle ?? CoCaptainReviewLifecycle()
        self.items = [CoCaptainViewModel.greetingItem()]
        bindReviewSessionIfNeeded()
    }

    public func clearHistory() {
        activeReviewSession().clear()
        items = [CoCaptainViewModel.greetingItem()]
        agentCoordinator.resetChat(scope: scope)
        if case .node(let nodeID) = scope {
            store?.clearNodeAgentMessages(id: nodeID)
            loadPersistedNodeMessages(nodeID: nodeID)
        }
        lastScrollPosition = nil
        lastTurnCompletion = nil
    }

    public func configureProjectSession(store: ProjectStore?, dispatcher: (any AppActionPerforming)?) {
        self.scope = .project
        self.focusedNodeID = nil
        self.store = store
        self.actionDispatcher = dispatcher
        bindReviewSessionIfNeeded()
    }

    public func configureNodeSession(store: ProjectStore, nodeID: UUID, dispatcher: (any AppActionPerforming)? = nil) {
        let newScope: CoCaptainAgentScope = .node(nodeID)
        if scope != newScope {
            streamingTask?.cancel()
            streamingTask = nil
            isThinking = false
            lastScrollPosition = nil
        }

        self.scope = newScope
        self.focusedNodeID = nodeID
        self.store = store
        self.actionDispatcher = dispatcher
        bindReviewSessionIfNeeded()
        loadPersistedNodeMessages(nodeID: nodeID)
        runAnalysis()
    }

    /// Nodes available for inline @ mention suggestions (Mini-Apps first, then others).
    public var pinnableContextNodes: [SpatialNode] {
        guard scope == .project, let nodes = store?.nodes else { return [] }
        return nodes.sorted { lhs, rhs in
            if lhs.type == .miniApp && rhs.type != .miniApp { return true }
            if lhs.type != .miniApp && rhs.type == .miniApp { return false }
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }

    public func setPresented(_ presented: Bool) {
        if !presented {
            streamingTask?.cancel()
            streamingTask = nil
            isThinking = false
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = presented
        }

        if presented {
            runAnalysis()
        }
    }

    public func runAnalysis() {
        guard let nodes = store?.nodes else { return }
        let newSuggestions = analyzer.analyze(nodes: nodes)
        
        // Only update if suggestions have changed to avoid UI flickering
        if newSuggestions != analysisItems {
            withAnimation(.spring()) {
                analysisItems = newSuggestions
            }
        }
    }

    public func dismissSuggestion(_ suggestion: ProjectSuggestion) {
        withAnimation(.spring()) {
            analysisItems.removeAll(where: { $0.id == suggestion.id })
        }
    }

    public func applySuggestion(_ suggestion: ProjectSuggestion) {
        dismissSuggestion(suggestion)
        sendMessage(suggestion.suggestedPrompt)
    }

    @discardableResult
    public func sendMessage(
        _ text: String,
        mentions: [CoCaptainNodeMention] = [],
        attachments: [CoCaptainAttachment] = [],
        purpose: CoCaptainTurnPurpose = .standard
    ) -> Bool {
        guard !isThinking else { return false }

        if let error = agentCoordinator.submissionError(for: attachments) {
            appendAssistantMessage(error.localizedDescription)
            return false
        }

        let turnID = UUID()
        let userItem = ChatBubbleItem(
            text: text,
            isUser: true,
            mentions: mentions,
            attachments: attachments
        )
        items.append(CoCaptainTimelineItem(content: .message(userItem)))
        persistNodeMessageIfNeeded(userItem)
        requestScrollToBottom()

        if purpose == .standard,
           handleDirectCommand(text, turnID: turnID, purpose: purpose) {
            return true
        }

        isThinking = true
        let aiMessageID = UUID()
        items.append(
            CoCaptainTimelineItem(
                id: aiMessageID,
                content: .message(ChatBubbleItem(id: aiMessageID, text: "", isUser: false))
            )
        )

        streamingTask = Task { @MainActor in
            defer {
                streamingTask = nil
                isThinking = false
            }

            do {
                let turnPlan = CoCaptainTurnPlan(
                    purpose: purpose,
                    mode: chatMode
                )
                let contextFocus = scope == .project
                    ? mentions.map(\.nodeID).filter { nodeID in
                        store?.nodes.contains(where: { $0.id == nodeID }) == true
                    }
                    : []

                let result = try await agentCoordinator.run(
                    userMessage: text,
                    store: store,
                    dispatcher: actionDispatcher,
                    scope: scope,
                    purpose: purpose,
                    turnPlan: turnPlan,
                    contextFocusNodeIDs: Array(Set(contextFocus)),
                    attachments: attachments,
                    onVisibleText: { [weak self] visible in
                        guard let self else { return }
                        // Adapter strips machine payloads (XML fences); only prose reaches the bubble.
                        self.updateMessage(id: aiMessageID, text: visible)
                        self.requestScrollToBottom()
                    }
                )

                let hasUsableResponse =
                    !result.visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    result.executionSummary != nil ||
                    result.reviewDraft != nil ||
                    result.clarifyingQuestion != nil

                if purpose.isConversationalTurn, !hasUsableResponse {
                    updateMessage(id: aiMessageID, text: onboardingRetryMessage(for: purpose))
                    markAssistantResponseCompleted(
                        turnID: turnID,
                        purpose: purpose,
                        successful: false
                    )
                    return
                }

                // Finalize the streamed bubble as the preamble (or remove if still empty).
                let finalizedProse = result.preamble.isEmpty ? result.visibleText : result.preamble
                if finalizedProse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    removeEmptyMessage(id: aiMessageID)
                } else {
                    finalizeAssistantMessage(id: aiMessageID, text: finalizedProse)
                }

                // Optional second bubble for payload assistant_message when it differs from preamble.
                if let payloadMsg = result.payloadMessage,
                   !payloadMsg.isEmpty,
                   payloadMsg != finalizedProse {
                    appendAssistantMessage(payloadMsg)
                }

                if let executionSummary = result.executionSummary {
                    items.append(CoCaptainTimelineItem(content: .execution(executionSummary)))
                }

                var presentedReviewBundle = false
                if let reviewDraft = result.reviewDraft,
                   let record = stageReviewDraft(reviewDraft) {
                    appendReviewRecord(record)
                    presentedReviewBundle = true
                } else if purpose == .onboardingGuidedEdit {
                    presentOnboardingReviewFallback(turnID: turnID, replacingMessageID: aiMessageID)
                    return
                }

                if let question = result.clarifyingQuestion {
                    items.append(
                        CoCaptainTimelineItem(
                            content: .clarifyingQuestion(
                                CoCaptainClarifyingQuestionItem(question: question)
                            )
                        )
                    )
                }
                requestScrollToBottom()
                markAssistantResponseCompleted(
                    turnID: turnID,
                    purpose: purpose,
                    successful: hasUsableResponse,
                    presentedReviewBundle: presentedReviewBundle
                )
            } catch {
                if error is CancellationError || Task.isCancelled {
                    removeEmptyMessage(id: aiMessageID)
                    recordTurnCompletion(
                        turnID: turnID,
                        purpose: purpose,
                        successful: false
                    )
                    return
                }

                if purpose == .onboardingGuidedEdit {
                    presentOnboardingReviewFallback(turnID: turnID, replacingMessageID: aiMessageID)
                    return
                }

                if let limitError = error as? TokenUsageLimitError {
                    updateMessage(id: aiMessageID, text: limitError.localizedDescription)
                    appendLimitReachedCTA()
                } else if purpose.isConversationalTurn {
                    updateMessage(id: aiMessageID, text: onboardingRetryMessage(for: purpose))
                } else {
                    updateMessage(
                        id: aiMessageID,
                        text: userFacingModelErrorMessage(from: error)
                    )
                }
                markAssistantResponseCompleted(
                    turnID: turnID,
                    purpose: purpose,
                    successful: false
                )
            }
        }
        return true
    }

    public func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isThinking = false

        // Drop only an empty thinking placeholder; keep any prose already streamed.
        if let lastMessage, !lastMessage.isUser {
            removeEmptyMessage(id: lastMessage.id)
        }
    }

    public func performProductCTA(_ item: CoCaptainProductCTAItem) {
        _ = actionDispatcher?.perform(item.actionID, source: .user, arguments: nil)
    }

    public func flyToReviewTarget(_ nodeID: UUID) {
        onFlyToNode?(nodeID)
    }

    /// Handles simple app commands locally so navigation does not need a model
    /// round trip. Mutating commands still become review items.
    ///
    /// In Ask/Plan modes, mutating command shortcuts are disabled so those
    /// messages go to the model as chat instead of executing or staging canvas changes.
    private func handleDirectCommand(
        _ text: String,
        turnID: UUID,
        purpose: CoCaptainTurnPurpose
    ) -> Bool {
        guard scope == .project else { return false }
        guard let actionDispatcher,
              let actionID = commandIntentResolver.resolve(text, availableActions: actionDispatcher.availableActions),
              let definition = actionDispatcher.definition(for: actionID) else {
            return false
        }

        if chatMode.isProseOnly, definition.isMutating {
            return false
        }

        if !definition.allowsAutonomousExecution {
            items.append(
                CoCaptainTimelineItem(
                    content: .message(
                        ChatBubbleItem(
                            text: LocalizationManager.shared.localizedString(
                                "I can do that. Review the action below, then tap Apply."
                            ),
                            isUser: false
                        )
                    )
                )
            )
            let reviewDraft = CoCaptainReviewLifecycle.Draft(
                pendingActions: [CoCaptainAgentAction(actionID: actionID.rawValue)]
            )
            if let record = stageReviewDraft(reviewDraft) {
                appendReviewRecord(record)
            }
            markAssistantResponseCompleted(
                turnID: turnID,
                purpose: purpose,
                successful: true
            )
            return true
        }

        store?.createAutoCheckpoint(label: "Before AI Actions")
        let result = actionDispatcher.perform(actionID, source: .agentAutomatic, arguments: nil)
        items.append(
            CoCaptainTimelineItem(
                content: .execution(ExecutionStatusItem(summary: result.message))
            )
        )
        markAssistantResponseCompleted(
            turnID: turnID,
            purpose: purpose,
            successful: true
        )
        return true
    }

    public func applyReviewItem(bundleID: UUID, itemID: UUID) {
        resolveReviewDecision(.approve(itemID: itemID), in: bundleID)
    }

    public func rejectReviewItem(bundleID: UUID, itemID: UUID) {
        resolveReviewDecision(.reject(itemID: itemID), in: bundleID)
    }

    public func resolveClarification(bundleID: UUID, itemID: UUID, candidateID: UUID) {
        resolveReviewDecision(
            .chooseClarification(itemID: itemID, candidateID: candidateID),
            in: bundleID
        )
    }

    /// Records the tapped option on a clarifying-question card and sends it as
    /// the user's next message so the conversation continues naturally.
    public func answerClarifyingQuestion(itemID: UUID, option: String) {
        guard !isThinking,
              let index = items.firstIndex(where: { $0.id == itemID }),
              case .clarifyingQuestion(var questionItem) = items[index].content,
              questionItem.answeredOption == nil else {
            return
        }

        questionItem.answeredOption = option
        items[index].content = .clarifyingQuestion(questionItem)
        sendMessage(option)
    }

    public func applyAll(in bundleID: UUID) {
        resolveReviewDecision(.approveAll, in: bundleID)
    }

    public func rejectAll(in bundleID: UUID) {
        resolveReviewDecision(.rejectAll, in: bundleID)
    }

    /// Resets chat state when the active project changes so streamed responses
    /// and review bundles cannot leak across project contexts.
    private func handleStoreChange() {
        let currentStoreID = store.map { ObjectIdentifier($0) }
        bindReviewSessionIfNeeded()
        guard currentStoreID != lastStoreID else { return }
        defer { lastStoreID = currentStoreID }

        if scope == .project, lastStoreID != nil {
            streamingTask?.cancel()
            streamingTask = nil
            isThinking = false
            clearHistory()
        }
        
        runAnalysis()
    }

    private func activeReviewSession() -> CoCaptainReviewLifecycle.Session {
        bindReviewSessionIfNeeded()
        guard let reviewSession else {
            preconditionFailure("Review lifecycle session was not configured.")
        }
        return reviewSession
    }

    private func bindReviewSessionIfNeeded() {
        let currentStoreID = store.map { ObjectIdentifier($0) }
        let currentDispatcherID = actionDispatcher.map { ObjectIdentifier($0) }

        if let reviewSession,
           reviewSessionScope == scope,
           reviewSessionStoreID == currentStoreID {
            if reviewSessionDispatcherID != currentDispatcherID {
                reviewSession.updateDispatcher(actionDispatcher)
                reviewSessionDispatcherID = currentDispatcherID
            }
            return
        }

        reviewSession = reviewLifecycle.session(
            scope: scope,
            store: store,
            dispatcher: actionDispatcher
        )
        reviewSessionScope = scope
        reviewSessionStoreID = currentStoreID
        reviewSessionDispatcherID = currentDispatcherID
    }

    @discardableResult
    private func stageReviewDraft(
        _ draft: CoCaptainReviewLifecycle.Draft,
        createdAt: Date = Date()
    ) -> CoCaptainReviewLifecycle.Record? {
        activeReviewSession().stage(draft, createdAt: createdAt)
    }

    private func appendReviewRecord(_ record: CoCaptainReviewLifecycle.Record) {
        items.append(
            CoCaptainTimelineItem(
                id: record.id,
                content: .reviewBundle(record.bundle)
            )
        )
    }

    private func resolveReviewDecision(
        _ decision: CoCaptainReviewLifecycle.Decision,
        in bundleID: UUID
    ) {
        switch activeReviewSession().resolve(decision, in: bundleID) {
        case .failure:
            return
        case .success(let transition):
            guard let bundleIndex = items.firstIndex(where: { $0.id == transition.record.id }) else {
                return
            }
            items[bundleIndex].content = .reviewBundle(transition.record.bundle)
            renderReviewEffects(transition.effects, bundleID: transition.record.id)
        }
    }

    private func renderReviewEffects(
        _ effects: [CoCaptainReviewLifecycle.Effect],
        bundleID: UUID
    ) {
        for effect in effects {
            switch effect {
            case .nodeEditApplied(let itemID, _, let role, _):
                items.append(
                    CoCaptainTimelineItem(
                        content: .execution(
                            ExecutionStatusItem(
                                summary: LocalizationManager.shared.localizedString(
                                    "Applied updates to %@.",
                                    arguments: [role.localizedDisplayName]
                                )
                            )
                        )
                    )
                )
                onReviewItemApplied?(bundleID, itemID)

            case .appActionPerformed(let itemID, let result):
                items.append(
                    CoCaptainTimelineItem(
                        content: .execution(ExecutionStatusItem(summary: result.message))
                    )
                )
                onReviewItemApplied?(bundleID, itemID)

            case .learningNote(_, let note):
                items.append(
                    CoCaptainTimelineItem(
                        content: .mentorNote(CoCaptainMentorNoteItem(note: note))
                    )
                )

            case .rejected, .clarificationResolved, .conflicted:
                break
            }
        }
    }

    private func updateMessage(id: UUID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if case .message(var bubble) = items[index].content {
            bubble.text = text
            items[index].content = .message(bubble)
        }
    }

    /// Writes the final assistant prose into the streamed bubble and persists it
    /// for node-scoped sessions (streaming updates stay ephemeral until finalize).
    private func finalizeAssistantMessage(id: UUID, text: String) {
        updateMessage(id: id, text: text)
        guard let index = items.firstIndex(where: { $0.id == id }),
              case .message(let bubble) = items[index].content else {
            return
        }
        persistNodeMessageIfNeeded(bubble)
    }

    private func removeEmptyMessage(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              case .message(let bubble) = items[index].content,
              !bubble.isUser,
              bubble.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        items.remove(at: index)
    }

    /// Increments the completed response count to signal to subscribers that the assistant
    /// has finished processing the current request/action.
    private func markAssistantResponseCompleted(
        turnID: UUID,
        purpose: CoCaptainTurnPurpose,
        successful: Bool,
        presentedReviewBundle: Bool = false
    ) {
        completedAssistantResponseCount += 1
        if successful {
            successfulAssistantResponseCount += 1
        }
        recordTurnCompletion(
            turnID: turnID,
            purpose: purpose,
            successful: successful,
            presentedReviewBundle: presentedReviewBundle
        )
    }

    private func recordTurnCompletion(
        turnID: UUID,
        purpose: CoCaptainTurnPurpose,
        successful: Bool,
        presentedReviewBundle: Bool = false
    ) {
        lastTurnCompletion = CoCaptainTurnCompletion(
            turnID: turnID,
            purpose: purpose,
            succeeded: successful,
            presentedReviewBundle: presentedReviewBundle
        )
    }

    private func presentOnboardingReviewFallback(
        turnID: UUID,
        replacingMessageID: UUID
    ) {
        removeEmptyMessage(id: replacingMessageID)

        guard case .node(let nodeID) = scope,
              let store,
              let node = store.nodes.first(where: { $0.id == nodeID }),
              let baseText = node.miniApp?.codeText else {
            markAssistantResponseCompleted(
                turnID: turnID,
                purpose: .onboardingGuidedEdit,
                successful: false
            )
            return
        }

        appendAssistantMessage(
            LocalizationManager.shared.localizedString(
                "onboarding.guidedEdit.fallback.message"
            )
        )
        let draft = OnboardingCoCaptainReviewFixture.makeDraft(
            nodeID: nodeID,
            baseText: baseText
        )
        guard let record = stageReviewDraft(draft) else {
            markAssistantResponseCompleted(
                turnID: turnID,
                purpose: .onboardingGuidedEdit,
                successful: false
            )
            return
        }
        appendReviewRecord(record)
        onOnboardingReviewFallback?()
        requestScrollToBottom()
        markAssistantResponseCompleted(
            turnID: turnID,
            purpose: .onboardingGuidedEdit,
            successful: true,
            presentedReviewBundle: true
        )
    }

    private func userFacingModelErrorMessage(from error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !localized.isEmpty {
            return LocalizationManager.shared.localizedString(
                "Sorry, I hit an error while contacting the model.\n\n%@",
                arguments: [localized]
            )
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return LocalizationManager.shared.localizedString(
                "Sorry, I hit an error while contacting the model.\n\n%@",
                arguments: [description]
            )
        }

        return LocalizationManager.shared.localizedString(
            "Sorry, I hit an error while contacting the model. Please try again."
        )
    }

    private func onboardingRetryMessage(for purpose: CoCaptainTurnPurpose) -> String {
        switch purpose {
        case .onboardingWelcome:
            return LocalizationManager.shared.localizedString(
                "I couldn't finish your welcome. Please try sending your message again."
            )
        case .onboardingBuildHandoff:
            return LocalizationManager.shared.localizedString(
                "I couldn't finish preparing our next step. Please try sending your idea again."
            )
        case .onboardingGuidedEdit:
            return LocalizationManager.shared.localizedString(
                "I couldn't prepare that change. Please try asking again."
            )
        case .standard:
            return LocalizationManager.shared.localizedString(
                "Sorry, I couldn't finish that response. Please try again."
            )
        }
    }

    private var lastMessage: ChatBubbleItem? {
        guard case .message(let bubble) = items.last?.content else { return nil }
        return bubble
    }

    private static func greetingItem() -> CoCaptainTimelineItem {
        CoCaptainTimelineItem(
            content: .message(
                ChatBubbleItem(
                    text: LocalizationManager.shared.localizedString("Hello! I'm your Co-Captain. How can I help you build today?"),
                    isUser: false
                )
            )
        )
    }

    private func appendAssistantMessage(_ text: String) {
        let bubble = ChatBubbleItem(text: text, isUser: false)
        items.append(CoCaptainTimelineItem(content: .message(bubble)))
        persistNodeMessageIfNeeded(bubble)
    }

    private func appendLimitReachedCTA() {
        items.append(
            CoCaptainTimelineItem(
                content: .productCTA(
                    CoCaptainProductCTAItem(
                        title: LocalizationManager.shared.localizedString("Free CoCaptain usage reached"),
                        message: LocalizationManager.shared.localizedString("You've used this month's free CoCaptain help. Pro keeps CoCaptain available whenever you need it."),
                        primaryButtonTitle: LocalizationManager.shared.localizedString("View Pro"),
                        actionID: .proSubscription
                    )
                )
            )
        )
    }

    private func persistNodeMessageIfNeeded(_ bubble: ChatBubbleItem) {
        guard case .node(let nodeID) = scope else { return }
        store?.appendNodeAgentMessage(
            id: nodeID,
            message: NodeAgentMessage(
                id: bubble.id,
                text: bubble.text,
                isUser: bubble.isUser,
                mentions: bubble.mentions,
                attachments: bubble.attachments
            )
        )
    }

    private func loadPersistedNodeMessages(nodeID: UUID) {
        guard let node = store?.nodes.first(where: { $0.id == nodeID }) else {
            items = [CoCaptainViewModel.nodeGreetingItem(title: LocalizationManager.shared.localizedString("this node"))]
            return
        }

        let messages = node.agentState.messages.sorted { $0.createdAt < $1.createdAt }
        var timeline: [(Date, CoCaptainTimelineItem)] = messages.map { message in
            (
                message.createdAt,
                CoCaptainTimelineItem(
                    id: message.id,
                    content: .message(
                        ChatBubbleItem(
                            id: message.id,
                            text: message.text,
                            isUser: message.isUser,
                            mentions: message.mentions,
                            attachments: message.attachments
                        )
                    )
                )
            )
        }

        for record in activeReviewSession().records {
            timeline.append(
                (
                    record.createdAt,
                    CoCaptainTimelineItem(id: record.id, content: .reviewBundle(record.bundle))
                )
            )
        }

        if timeline.isEmpty {
            items = [CoCaptainViewModel.nodeGreetingItem(title: node.displayTitle)]
        } else {
            items = timeline.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private static func nodeGreetingItem(title: String) -> CoCaptainTimelineItem {
        CoCaptainTimelineItem(
            content: .message(
                ChatBubbleItem(
                    text: LocalizationManager.shared.localizedString("This node has its own Co-Captain context. Ask for focused changes to %@.", arguments: [title]),
                    isUser: false
                )
            )
        )
    }
}
