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
    public var actionDispatcher: (any AppActionPerforming)?

    /// Tracks the ID of the message that was last visible to the user.
    public var lastScrollPosition: UUID?

    @ObservationIgnored
    private let agentCoordinator: CoCaptainAgentCoordinator
    @ObservationIgnored
    private let commandIntentResolver = CommandIntentResolver()
    @ObservationIgnored
    private let patchEngine = NodePatchEngine()
    @ObservationIgnored
    private var lastStoreFileName: String?
    @ObservationIgnored
    private var streamingTask: Task<Void, Never>?
    @ObservationIgnored
    private var activeCodingRunItemID: UUID?

    public var isThinking: Bool = false
    /// The cumulative number of completed assistant turns/responses. This increments whenever a model
    /// streaming task, execution result, or local command finishes. Used to synchronize onboarding prompts.
    public private(set) var completedAssistantResponseCount: Int = 0
    /// The cumulative number of assistant turns that produced a usable response.
    /// Errors remain completed turns but do not advance this counter.
    public private(set) var successfulAssistantResponseCount: Int = 0
    /// The most recent terminal outcome, including the purpose of the exact turn
    /// that completed. Onboarding observes this instead of global counters.
    public private(set) var lastTurnCompletion: CoCaptainTurnCompletion?
    public var isAwaitingFirstResponse: Bool {
        guard isThinking,
              let lastMessage,
              !lastMessage.isUser else {
            return false
        }
        return lastMessage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        agentCoordinator: CoCaptainAgentCoordinator? = nil
    ) {
        self.agentCoordinator = agentCoordinator ?? CoCaptainAgentCoordinator()
        self.items = [CoCaptainViewModel.greetingItem()]
    }

    public func clearHistory() {
        cancelActiveCodingRun()
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
    }

    public func configureNodeSession(store: ProjectStore, nodeID: UUID, dispatcher: (any AppActionPerforming)? = nil) {
        let newScope: CoCaptainAgentScope = .node(nodeID)
        if scope != newScope {
            cancelActiveCodingRun()
            streamingTask?.cancel()
            streamingTask = nil
            isThinking = false
            lastScrollPosition = nil
        }

        self.scope = newScope
        self.focusedNodeID = nodeID
        self.store = store
        self.actionDispatcher = dispatcher
        loadPersistedNodeMessages(nodeID: nodeID)
        runAnalysis()
    }

    public func setPresented(_ presented: Bool) {
        if !presented {
            cancelActiveCodingRun()
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

    public func sendMessage(
        _ text: String,
        purpose: CoCaptainTurnPurpose = .standard
    ) {
        guard !isThinking else { return }

        let turnID = UUID()
        let userItem = ChatBubbleItem(text: text, isUser: true)
        items.append(CoCaptainTimelineItem(content: .message(userItem)))
        persistNodeMessageIfNeeded(userItem)

        if purpose == .standard,
           handleDirectCommand(text, turnID: turnID, purpose: purpose) {
            return
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
                let result = try await agentCoordinator.run(
                    userMessage: text,
                    store: store,
                    dispatcher: actionDispatcher,
                    scope: scope,
                    purpose: purpose,
                    onCodingProgress: { [weak self] state in
                        self?.updateCodingRun(state)
                    },
                    onVisibleText: { _ in
                        // Stop streaming characters to the UI for a cleaner 'split message' feel.
                    }
                )

                let hasUsableResponse =
                    !result.visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    result.executionSummary != nil ||
                    result.reviewBundle != nil

                if purpose.isConversationalTurn, !hasUsableResponse {
                    updateMessage(id: aiMessageID, text: onboardingRetryMessage(for: purpose))
                    markAssistantResponseCompleted(
                        turnID: turnID,
                        purpose: purpose,
                        successful: false
                    )
                    return
                }

                // Remove the empty thinking placeholder.
                removeEmptyMessage(id: aiMessageID)

                // 1. Add Preamble bubble (the conversational part).
                if !result.preamble.isEmpty {
                    appendAssistantMessage(result.preamble)
                }

                // 2. Add Payload Message bubble (the intent summary).
                if let payloadMsg = result.payloadMessage, !payloadMsg.isEmpty, payloadMsg != result.preamble {
                    appendAssistantMessage(payloadMsg)
                }

                if let executionSummary = result.executionSummary {
                    items.append(CoCaptainTimelineItem(content: .execution(executionSummary)))
                }

                if let reviewBundle = result.reviewBundle {
                    items.append(CoCaptainTimelineItem(content: .reviewBundle(reviewBundle)))
                }
                markAssistantResponseCompleted(
                    turnID: turnID,
                    purpose: purpose,
                    successful: hasUsableResponse
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

                if let limitError = error as? TokenUsageLimitError {
                    updateMessage(id: aiMessageID, text: limitError.localizedDescription)
                    appendLimitReachedCTA()
                } else if purpose.isConversationalTurn {
                    updateMessage(id: aiMessageID, text: onboardingRetryMessage(for: purpose))
                } else {
                    let details = String(reflecting: error)
                    updateMessage(
                        id: aiMessageID,
                        text: LocalizationManager.shared.localizedString(
                            "Sorry, I hit an error while contacting the model.\n\n%@",
                            arguments: [details]
                        )
                    )
                }
                markAssistantResponseCompleted(
                    turnID: turnID,
                    purpose: purpose,
                    successful: false
                )
            }
        }
    }

    public func stopStreaming() {
        cancelActiveCodingRun()
        streamingTask?.cancel()
        streamingTask = nil
        isThinking = false

        if let lastMessage, !lastMessage.isUser {
            removeEmptyMessage(id: lastMessage.id)
        }
    }

    public func performProductCTA(_ item: CoCaptainProductCTAItem) {
        _ = actionDispatcher?.perform(item.actionID, source: .user, arguments: nil)
    }

    /// Handles simple app commands locally so navigation does not need a model
    /// round trip. Mutating commands still become review items.
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
            items.append(
                CoCaptainTimelineItem(
                    content: .reviewBundle(
                        ReviewBundleItem(
                            items: [
                                PendingReviewItem(
                                    targetLabel: definition.localizedTitle,
                                    summary: LocalizationManager.shared.localizedString(
                                        "Awaiting approval to run %@.",
                                        arguments: [definition.localizedTitle]
                                    ),
                                    preview: definition.localizedTitle,
                                    source: .appAction(actionID, nil) // args will be handled in handleDirectCommand if needed
                                )
                            ]
                        )
                    )
                )
            )
            markAssistantResponseCompleted(
                turnID: turnID,
                purpose: purpose,
                successful: true
            )
            return true
        }

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

    /// Applies one user-approved review item. Node edits are revalidated against
    /// their captured base text so stale AI suggestions cannot overwrite newer
    /// user edits.
    public func applyReviewItem(bundleID: UUID, itemID: UUID) {
        guard let bundleIndex = items.firstIndex(where: { $0.id == bundleID }),
              case .reviewBundle(var bundle) = items[bundleIndex].content,
              let itemIndex = bundle.items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        var item = bundle.items[itemIndex]
        
        // Create checkpoint before applying a single item
        store?.createCheckpoint(label: "Apply Suggestion: \(item.targetLabel)")

        switch item.source {
        case .appAction(let actionID, let arguments):
            let result = actionDispatcher?.perform(actionID, source: .agentApproved, arguments: arguments)
            item.status = result?.executed == true ? .applied : .conflicted
            if let result, result.executed {
                items.append(
                    CoCaptainTimelineItem(
                        content: .execution(ExecutionStatusItem(summary: result.message))
                    )
                )
            }
        case .nodeEdit(let role, let section, let operations, let baseText):
            guard let store,
                  let node = patchEngine.resolveNode(nodeID: item.targetNodeID, for: role, in: store) else {
                item.status = .conflicted
                item.conflictDescription = LocalizationManager.shared.localizedString("The node could not be found in the current project.")
                break
            }

            let currentText: String
            switch section {
            case .srs:
                currentText = node.miniApp?.srsText ?? ""
            case .code:
                currentText = node.miniApp?.codeText ?? ""
            }

            guard currentText == baseText else {
                item.status = .conflicted
                item.conflictDescription = LocalizationManager.shared.localizedString("This node was edited after the suggestion was generated. Ask Co-Captain to revise.")
                break
            }

            do {
                let preview = try patchEngine.preview(nodeID: item.targetNodeID, role: role, section: section, operations: operations, in: store)
                switch section {
                case .srs:
                    store.updateMiniAppSRS(id: node.id, text: preview.resultText, persist: true)
                case .code:
                    store.updateMiniAppCode(id: node.id, text: preview.resultText, persist: true)
                }
                item.status = .applied
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
            } catch {
                item.status = .conflicted
                item.conflictDescription = error.localizedDescription
            }
        }

        bundle.items[itemIndex] = item
        items[bundleIndex].content = .reviewBundle(bundle)
    }

    public func rejectReviewItem(bundleID: UUID, itemID: UUID) {
        updateReviewItem(bundleID: bundleID, itemID: itemID, status: .rejected)
    }

    public func applyAll(in bundleID: UUID) {
        guard let bundle = reviewBundle(for: bundleID) else { return }
        
        // Create one checkpoint for the whole bundle
        store?.createCheckpoint(label: "Apply All Changes")
        
        for itemID in bundle.items.filter({ $0.status == .pending }).map(\.id) {
            applyReviewItem(bundleID: bundleID, itemID: itemID)
        }
    }

    public func rejectAll(in bundleID: UUID) {
        guard let bundle = reviewBundle(for: bundleID) else { return }
        for itemID in bundle.items.filter({ $0.status == .pending }).map(\.id) {
            rejectReviewItem(bundleID: bundleID, itemID: itemID)
        }
    }

    /// Resets chat state when the active project changes so streamed responses
    /// and review bundles cannot leak across project contexts.
    private func handleStoreChange() {
        let currentFileName = store?.fileName
        guard currentFileName != lastStoreFileName else { return }
        defer { lastStoreFileName = currentFileName }

        if scope == .project, lastStoreFileName != nil {
            cancelActiveCodingRun()
            streamingTask?.cancel()
            streamingTask = nil
            isThinking = false
            clearHistory()
        }
        
        runAnalysis()
    }

    private func reviewBundle(for bundleID: UUID) -> ReviewBundleItem? {
        guard let bundleIndex = items.firstIndex(where: { $0.id == bundleID }),
              case .reviewBundle(let bundle) = items[bundleIndex].content else {
            return nil
        }
        return bundle
    }

    private func updateCodingRun(_ state: CoCaptainCodingRunState) {
        if let id = activeCodingRunItemID,
           let index = items.firstIndex(where: { $0.id == id }) {
            items[index].content = .codingRun(state)
        } else {
            let id = UUID()
            activeCodingRunItemID = id
            items.append(
                CoCaptainTimelineItem(
                    id: id,
                    content: .codingRun(state)
                )
            )
        }

        if state.isTerminal {
            activeCodingRunItemID = nil
        }
    }

    private func cancelActiveCodingRun() {
        guard let id = activeCodingRunItemID,
              let index = items.firstIndex(where: { $0.id == id }) else {
            activeCodingRunItemID = nil
            return
        }
        items[index].content = .codingRun(.cancelled)
        activeCodingRunItemID = nil
    }

    private func updateReviewItem(bundleID: UUID, itemID: UUID, status: ReviewItemStatus) {
        guard let bundleIndex = items.firstIndex(where: { $0.id == bundleID }),
              case .reviewBundle(var bundle) = items[bundleIndex].content,
              let itemIndex = bundle.items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        bundle.items[itemIndex].status = status
        items[bundleIndex].content = .reviewBundle(bundle)
    }

    private func updateMessage(id: UUID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if case .message(var bubble) = items[index].content {
            bubble.text = text
            items[index].content = .message(bubble)
        }
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
        successful: Bool
    ) {
        completedAssistantResponseCount += 1
        if successful {
            successfulAssistantResponseCount += 1
        }
        recordTurnCompletion(
            turnID: turnID,
            purpose: purpose,
            successful: successful
        )
    }

    private func recordTurnCompletion(
        turnID: UUID,
        purpose: CoCaptainTurnPurpose,
        successful: Bool
    ) {
        lastTurnCompletion = CoCaptainTurnCompletion(
            turnID: turnID,
            purpose: purpose,
            succeeded: successful
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
            message: NodeAgentMessage(id: bubble.id, text: bubble.text, isUser: bubble.isUser)
        )
    }

    private func loadPersistedNodeMessages(nodeID: UUID) {
        guard let node = store?.nodes.first(where: { $0.id == nodeID }) else {
            items = [CoCaptainViewModel.nodeGreetingItem(title: LocalizationManager.shared.localizedString("this node"))]
            return
        }

        let messages = node.agentState.messages.sorted { $0.createdAt < $1.createdAt }
        if messages.isEmpty {
            items = [CoCaptainViewModel.nodeGreetingItem(title: node.displayTitle)]
        } else {
            items = messages.map { message in
                CoCaptainTimelineItem(
                    id: message.id,
                    content: .message(ChatBubbleItem(id: message.id, text: message.text, isUser: message.isUser))
                )
            }
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
