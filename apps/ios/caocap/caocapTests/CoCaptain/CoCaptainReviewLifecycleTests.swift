import Foundation
import SwiftUI
import Testing
@testable import caocap

@MainActor
struct CoCaptainReviewLifecycleTests {
    @Test func stagingUniqueEditCapturesCanonicalIdentityWithoutMutation() throws {
        let store = makeStore()
        let nodeID = try #require(store.nodes.first?.id)
        let original = try #require(store.nodes.first?.miniApp?.codeText)
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: nil)

        let record = try #require(
            session.stage(
                draft(
                    nodeID: nodeID,
                    replacement: "<h1>Updated</h1>",
                    learningNote: nil
                )
            )
        )

        #expect(record.id == record.bundle.id)
        #expect(record.bundle.items.first?.status == .pending)
        #expect(record.bundle.items.first?.beforePreview?.contains("Hello World!") == true)
        #expect(record.bundle.items.first?.preview.contains("Updated") == true)
        #expect(record.bundle.items.first?.learningNote != nil)
        #expect(store.nodes.first?.miniApp?.codeText == original)
    }

    @Test func stagingAmbiguousMissingAndUnavailableWorkProducesExplicitOutcomes() throws {
        let ambiguousStore = makeAmbiguousStore()
        let ambiguousNodeID = try #require(ambiguousStore.nodes.first?.id)
        let ambiguousSession = CoCaptainReviewLifecycle()
            .session(scope: .project, store: ambiguousStore, dispatcher: nil)
        let ambiguousRecord = try #require(
            ambiguousSession.stage(
                CoCaptainReviewLifecycle.Draft(
                    nodeEdits: [
                        CoCaptainNodeEditProposal(
                            nodeID: ambiguousNodeID,
                            summary: "Rename one label",
                            operations: [
                                NodePatchOperation(
                                    type: .replaceExact,
                                    target: "Repeat me",
                                    content: "Chosen"
                                )
                            ]
                        )
                    ]
                )
            )
        )

        #expect(ambiguousRecord.bundle.items.first?.status == .needsClarification)
        #expect(ambiguousRecord.bundle.items.first?.clarificationCandidates?.count == 2)

        let missingRecord = try #require(
            CoCaptainReviewLifecycle()
                .session(scope: .project, store: ambiguousStore, dispatcher: nil)
                .stage(draft(nodeID: UUID(), replacement: "Missing"))
        )
        #expect(missingRecord.bundle.items.first?.status == .conflicted)

        let unavailableRecord = try #require(
            CoCaptainReviewLifecycle()
                .session(scope: .project, store: ambiguousStore, dispatcher: nil)
                .stage(
                    CoCaptainReviewLifecycle.Draft(
                        pendingActions: [
                            CoCaptainAgentAction(actionID: "launch_rocket")
                        ]
                    )
                )
        )
        let unavailableItem = try #require(unavailableRecord.bundle.items.first)
        #expect(unavailableItem.status == .conflicted)
        guard case .unavailableAction(let actionID, _) = unavailableItem.source else {
            Issue.record("Expected an explicit unavailable action source")
            return
        }
        #expect(actionID == "launch_rocket")

        let noStoreRecord = try #require(
            CoCaptainReviewLifecycle()
                .session(scope: .project, store: nil, dispatcher: nil)
                .stage(draft(nodeID: ambiguousNodeID, replacement: "No store"))
        )
        #expect(noStoreRecord.bundle.items.first?.status == .conflicted)
    }

    @Test func clarificationRestagesWithoutMutatingCanvas() throws {
        let store = makeAmbiguousStore()
        let nodeID = try #require(store.nodes.first?.id)
        let original = try #require(store.nodes.first?.miniApp?.codeText)
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: nil)
        let record = try #require(
            session.stage(
                CoCaptainReviewLifecycle.Draft(
                    nodeEdits: [
                        CoCaptainNodeEditProposal(
                            nodeID: nodeID,
                            summary: "Rename one label",
                            operations: [
                                NodePatchOperation(
                                    type: .replaceExact,
                                    target: "Repeat me",
                                    content: "Chosen"
                                )
                            ]
                        )
                    ]
                )
            )
        )
        let item = try #require(record.bundle.items.first)
        let candidate = try #require(item.clarificationCandidates?.first)

        let transition = try session.resolve(
            .chooseClarification(itemID: item.id, candidateID: candidate.id),
            in: record.id
        ).get()

        let updated = try #require(transition.record.bundle.items.first)
        #expect(updated.status == .pending)
        #expect(updated.clarificationCandidates == nil)
        #expect(transition.effects == [.clarificationResolved(itemID: item.id)])
        #expect(store.nodes.first?.miniApp?.codeText == original)
        #expect(store.history.isEmpty)
    }

    @Test func approvalAppliesEditAndReturnsOrderedLearningEffects() async throws {
        let store = makeStore()
        let nodeID = try #require(store.nodes.first?.id)
        let note = CoCaptainLearningNote(
            concept: "Headings",
            body: "The main heading introduces the page."
        )
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: nil)
        let record = try #require(
            session.stage(
                draft(
                    nodeID: nodeID,
                    replacement: "<h1>Approved</h1>",
                    learningNote: note
                )
            )
        )
        let itemID = try #require(record.bundle.items.first?.id)

        let transition = try session.resolve(
            .approve(itemID: itemID),
            in: record.id
        ).get()

        #expect(transition.record.bundle.items.first?.status == .applied)
        #expect(store.nodes.first?.miniApp?.codeText == "<h1>Approved</h1>")
        let checkpointWasPersisted = await waitUntil {
            store.history.count == 1
        }
        #expect(checkpointWasPersisted)
        #expect(store.history.count == 1)
        #expect(transition.effects.count == 2)
        guard case .nodeEditApplied(let appliedID, let appliedNodeID, _, _) = transition.effects[0],
              case .learningNote(let learningID, let returnedNote) = transition.effects[1] else {
            Issue.record("Expected applied then learning effects")
            return
        }
        #expect(appliedID == itemID)
        #expect(learningID == itemID)
        #expect(returnedNote == note)
        #expect(appliedNodeID == store.nodes.first?.id)
    }

    @Test func staleApprovalConflictsWithoutMutatingOverNewerText() throws {
        let store = makeStore()
        let nodeID = try #require(store.nodes.first?.id)
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: nil)
        let record = try #require(
            session.stage(draft(nodeID: nodeID, replacement: "<h1>Suggested</h1>"))
        )
        let itemID = try #require(record.bundle.items.first?.id)
        store.updateMiniAppCode(id: nodeID, text: "<h1>User edit</h1>", persist: false)

        let transition = try session.resolve(
            .approve(itemID: itemID),
            in: record.id
        ).get()

        #expect(transition.record.bundle.items.first?.status == .conflicted)
        #expect(store.nodes.first?.miniApp?.codeText == "<h1>User edit</h1>")
        #expect(transition.effects.contains { effect in
            if case .conflicted(let conflictedID, _) = effect {
                return conflictedID == itemID
            }
            return false
        })
    }

    @Test func appActionRequiresApprovalAndUsesAgentApprovedSource() throws {
        let store = makeStore()
        let dispatcher = LifecycleActionDispatcher()
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: dispatcher)
        let record = try #require(
            session.stage(
                CoCaptainReviewLifecycle.Draft(
                    pendingActions: [
                        CoCaptainAgentAction(
                            actionID: AppActionID.createNode.rawValue,
                            args: ["title": "New"]
                        )
                    ]
                )
            )
        )
        let itemID = try #require(record.bundle.items.first?.id)
        #expect(dispatcher.performed.isEmpty)

        let transition = try session.resolve(
            .approve(itemID: itemID),
            in: record.id
        ).get()

        #expect(transition.record.bundle.items.first?.status == .applied)
        #expect(dispatcher.performed.first?.source == .agentApproved)
        #expect(dispatcher.performed.first?.arguments == ["title": "New"])
    }

    @Test func failedAppActionBecomesTerminalConflict() throws {
        let dispatcher = LifecycleActionDispatcher(executed: false)
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: makeStore(), dispatcher: dispatcher)
        let record = try #require(
            session.stage(
                CoCaptainReviewLifecycle.Draft(
                    pendingActions: [
                        CoCaptainAgentAction(actionID: AppActionID.createNode.rawValue)
                    ]
                )
            )
        )
        let itemID = try #require(record.bundle.items.first?.id)

        let transition = try session.resolve(
            .approve(itemID: itemID),
            in: record.id
        ).get()

        #expect(transition.record.bundle.items.first?.status == .conflicted)
        #expect(session.hasUnresolvedReviews == false)
    }

    @Test func applyAllUsesOneCheckpointAndContinuesAfterConflict() async throws {
        let first = SpatialNode(
            type: .miniApp,
            position: .zero,
            title: "First",
            miniApp: MiniAppState(codeText: "<h1>First</h1>")
        )
        let second = SpatialNode(
            type: .miniApp,
            position: CGPoint(x: 100, y: 0),
            title: "Second",
            miniApp: MiniAppState(codeText: "<h1>Second</h1>")
        )
        let store = makeStore(nodes: [first, second])
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: nil)
        let record = try #require(
            session.stage(
                CoCaptainReviewLifecycle.Draft(
                    nodeEdits: [
                        proposal(nodeID: first.id, summary: "Update first", replacement: "Agent first"),
                        proposal(nodeID: second.id, summary: "Update second", replacement: "Agent second")
                    ]
                )
            )
        )
        store.updateMiniAppCode(id: first.id, text: "User first", persist: false)

        let transition = try session.resolve(.approveAll, in: record.id).get()

        #expect(transition.record.bundle.items[0].status == .conflicted)
        #expect(transition.record.bundle.items[1].status == .applied)
        #expect(store.nodes.first(where: { $0.id == first.id })?.miniApp?.codeText == "User first")
        #expect(store.nodes.first(where: { $0.id == second.id })?.miniApp?.codeText == "Agent second")
        let checkpointWasPersisted = await waitUntil {
            store.history.count == 1
        }
        #expect(checkpointWasPersisted)
        #expect(store.history.count == 1)
        #expect(transition.effects.count == 3)
    }

    @Test func rejectAllRejectsPendingAndClarificationItems() throws {
        let store = makeAmbiguousStore()
        let nodeID = try #require(store.nodes.first?.id)
        let dispatcher = LifecycleActionDispatcher()
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: dispatcher)
        let record = try #require(
            session.stage(
                CoCaptainReviewLifecycle.Draft(
                    pendingActions: [
                        CoCaptainAgentAction(actionID: AppActionID.createNode.rawValue)
                    ],
                    nodeEdits: [
                        CoCaptainNodeEditProposal(
                            nodeID: nodeID,
                            summary: "Rename one label",
                            operations: [
                                NodePatchOperation(
                                    type: .replaceExact,
                                    target: "Repeat me",
                                    content: "Chosen"
                                )
                            ]
                        )
                    ]
                )
            )
        )

        let transition = try session.resolve(.rejectAll, in: record.id).get()

        #expect(transition.record.bundle.items.allSatisfy { $0.status == .rejected })
        #expect(transition.effects.count == 2)
        #expect(dispatcher.performed.isEmpty)
    }

    @Test func callerFailuresDoNotChangeRecord() throws {
        let store = makeStore()
        let nodeID = try #require(store.nodes.first?.id)
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: nil)
        let record = try #require(
            session.stage(draft(nodeID: nodeID, replacement: "Updated"))
        )
        let itemID = try #require(record.bundle.items.first?.id)
        _ = try session.resolve(.reject(itemID: itemID), in: record.id).get()
        let before = try #require(session.records.first)

        let result = session.resolve(.approve(itemID: itemID), in: record.id)

        guard case .failure(.decisionNotAllowed(let failedID, .rejected)) = result else {
            Issue.record("Expected a typed invalid-transition failure")
            return
        }
        #expect(failedID == itemID)
        #expect(session.records.first == before)
    }

    @Test func nodePersistenceKeepsClarificationAndRemovesTerminalRecords() throws {
        let store = makeAmbiguousStore()
        let nodeID = try #require(store.nodes.first?.id)
        let lifecycle = CoCaptainReviewLifecycle()
        let session = lifecycle.session(
            scope: .node(nodeID),
            store: store,
            dispatcher: nil
        )
        let record = try #require(
            session.stage(
                CoCaptainReviewLifecycle.Draft(
                    nodeEdits: [
                        CoCaptainNodeEditProposal(
                            nodeID: nodeID,
                            summary: "Rename one label",
                            operations: [
                                NodePatchOperation(
                                    type: .replaceExact,
                                    target: "Repeat me",
                                    content: "Chosen"
                                )
                            ]
                        )
                    ]
                )
            )
        )

        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.count == 1)
        #expect(
            lifecycle.session(scope: .node(nodeID), store: store, dispatcher: nil)
                .records.first?.bundle.items.first?.status == .needsClarification
        )

        let itemID = try #require(record.bundle.items.first?.id)
        _ = try session.resolve(.reject(itemID: itemID), in: record.id).get()
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.isEmpty == true)
        #expect(session.records.first?.bundle.items.first?.status == .rejected)
    }

    @Test func interleavedNodeSessionsPreserveBundlesStagedByOtherSessions() throws {
        let store = makeStore()
        let nodeID = try #require(store.nodes.first?.id)
        let lifecycle = CoCaptainReviewLifecycle()
        let firstSession = lifecycle.session(
            scope: .node(nodeID),
            store: store,
            dispatcher: nil
        )
        let firstRecord = try #require(
            firstSession.stage(draft(nodeID: nodeID, replacement: "First"))
        )
        let firstItemID = try #require(firstRecord.bundle.items.first?.id)

        let secondSession = lifecycle.session(
            scope: .node(nodeID),
            store: store,
            dispatcher: nil
        )
        let secondRecord = try #require(
            secondSession.stage(draft(nodeID: nodeID, replacement: "Second"))
        )

        _ = try firstSession.resolve(
            .reject(itemID: firstItemID),
            in: firstRecord.id
        ).get()

        let restored = lifecycle.session(
            scope: .node(nodeID),
            store: store,
            dispatcher: nil
        )
        #expect(restored.records.map(\.id) == [secondRecord.id])
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.count == 1)
    }

    @Test func interleavedNodeSessionsMergeDecisionsWithinOneBundle() throws {
        let firstNode = SpatialNode(
            type: .miniApp,
            position: .zero,
            title: "First",
            miniApp: MiniAppState(codeText: "First")
        )
        let secondNode = SpatialNode(
            type: .miniApp,
            position: CGPoint(x: 100, y: 0),
            title: "Second",
            miniApp: MiniAppState(codeText: "Second")
        )
        let store = makeStore(nodes: [firstNode, secondNode])
        let lifecycle = CoCaptainReviewLifecycle()
        let firstSession = lifecycle.session(
            scope: .node(firstNode.id),
            store: store,
            dispatcher: nil
        )
        let record = try #require(
            firstSession.stage(
                CoCaptainReviewLifecycle.Draft(
                    nodeEdits: [
                        proposal(
                            nodeID: firstNode.id,
                            summary: "Update first",
                            replacement: "First updated"
                        ),
                        proposal(
                            nodeID: secondNode.id,
                            summary: "Update second",
                            replacement: "Second updated"
                        )
                    ]
                )
            )
        )
        let firstItemID = record.bundle.items[0].id
        let secondItemID = record.bundle.items[1].id
        let secondSession = lifecycle.session(
            scope: .node(firstNode.id),
            store: store,
            dispatcher: nil
        )

        _ = try firstSession.resolve(
            .reject(itemID: firstItemID),
            in: record.id
        ).get()
        let transition = try secondSession.resolve(
            .reject(itemID: secondItemID),
            in: record.id
        ).get()

        #expect(transition.record.bundle.items.allSatisfy { $0.status == .rejected })
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.isEmpty == true)
    }

    @Test func projectSessionsAreEphemeralAndClearIsScopeAware() throws {
        let store = makeStore()
        let nodeID = try #require(store.nodes.first?.id)
        let lifecycle = CoCaptainReviewLifecycle()
        let projectSession = lifecycle.session(
            scope: .project,
            store: store,
            dispatcher: nil
        )
        _ = projectSession.stage(draft(nodeID: nodeID, replacement: "Project"))

        #expect(projectSession.records.count == 1)
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.isEmpty == true)
        #expect(
            lifecycle.session(scope: .project, store: store, dispatcher: nil)
                .records.isEmpty
        )

        let nodeSession = lifecycle.session(
            scope: .node(nodeID),
            store: store,
            dispatcher: nil
        )
        _ = nodeSession.stage(draft(nodeID: nodeID, replacement: "Node"))
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.count == 1)
        nodeSession.clear()
        #expect(nodeSession.records.isEmpty)
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.isEmpty == true)
    }

    @Test func restoreNormalizesLegacyIdentityAndSkipsCorruptRecords() throws {
        let store = makeStore()
        let nodeID = try #require(store.nodes.first?.id)
        let legacyTimelineID = UUID()
        let bundle = ReviewBundleItem(
            id: UUID(),
            items: [
                PendingReviewItem(
                    targetLabel: "Mini-App CODE",
                    summary: "Legacy",
                    preview: "Updated",
                    source: .nodeEdit(
                        role: .miniApp,
                        section: .code,
                        operations: [
                            NodePatchOperation(type: .replaceAll, content: "Updated")
                        ],
                        baseText: try #require(store.nodes.first?.miniApp?.codeText)
                    )
                )
            ]
        )
        let legacy = LegacyReviewRecord(
            timelineItemID: legacyTimelineID,
            bundle: bundle,
            createdAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var state = try #require(store.nodes.first?.agentState)
        state.pendingReviewBundlesData = [
            Data("{not-json".utf8),
            try encoder.encode(legacy)
        ]
        store.updateNodeAgentState(id: nodeID, agentState: state, persist: false)

        let session = CoCaptainReviewLifecycle()
            .session(scope: .node(nodeID), store: store, dispatcher: nil)

        let restored = try #require(session.records.first)
        #expect(session.records.count == 1)
        #expect(restored.id == legacyTimelineID)
        #expect(restored.bundle.id == legacyTimelineID)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let normalizedData = try #require(
            store.nodes.first?.agentState.pendingReviewBundlesData.first
        )
        let normalized = try decoder.decode(
            CoCaptainReviewLifecycle.Record.self,
            from: normalizedData
        )
        #expect(normalized.id == normalized.bundle.id)
    }

    @Test func restoreRemovesCorruptPersistenceWithoutAnotherNormalizationTrigger() throws {
        let store = makeStore()
        let nodeID = try #require(store.nodes.first?.id)
        var state = try #require(store.nodes.first?.agentState)
        state.pendingReviewBundlesData = [Data("{not-json".utf8)]
        store.updateNodeAgentState(id: nodeID, agentState: state, persist: false)

        let session = CoCaptainReviewLifecycle()
            .session(scope: .node(nodeID), store: store, dispatcher: nil)

        #expect(session.records.isEmpty)
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.isEmpty == true)
        #expect(
            CoCaptainReviewLifecycle.hasUnresolvedPersistedRecords(
                in: try #require(store.nodes.first?.agentState)
            ) == false
        )
    }

    private func makeStore(nodes: [SpatialNode]? = nil) -> ProjectStore {
        ProjectStore(
            fileName: "review-lifecycle-\(UUID().uuidString).json",
            projectName: "Review Lifecycle",
            initialNodes: nodes ?? [
                SpatialNode(
                    type: .miniApp,
                    position: .zero,
                    title: "Mini-App",
                    miniApp: MiniAppState(codeText: "<h1>Hello World!</h1>")
                )
            ]
        )
    }

    private func makeAmbiguousStore() -> ProjectStore {
        makeStore(
            nodes: [
                SpatialNode(
                    type: .miniApp,
                    position: .zero,
                    title: "Mini-App",
                    miniApp: MiniAppState(
                        codeText: "<p>Repeat me</p><p>Repeat me</p>"
                    )
                )
            ]
        )
    }

    private func draft(
        nodeID: UUID,
        replacement: String,
        learningNote: CoCaptainLearningNote? = nil
    ) -> CoCaptainReviewLifecycle.Draft {
        CoCaptainReviewLifecycle.Draft(
            nodeEdits: [
                proposal(
                    nodeID: nodeID,
                    summary: "Update heading",
                    replacement: replacement,
                    learningNote: learningNote
                )
            ]
        )
    }

    private func proposal(
        nodeID: UUID,
        summary: String,
        replacement: String,
        learningNote: CoCaptainLearningNote? = nil
    ) -> CoCaptainNodeEditProposal {
        CoCaptainNodeEditProposal(
            nodeID: nodeID,
            role: .miniApp,
            section: .code,
            summary: summary,
            operations: [
                NodePatchOperation(type: .replaceAll, content: replacement)
            ],
            learningNote: learningNote
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !condition() {
            guard clock.now < deadline else { return false }
            try? await clock.sleep(for: .milliseconds(10))
        }
        return true
    }
}

private struct LegacyReviewRecord: Codable {
    let timelineItemID: UUID
    let bundle: ReviewBundleItem
    let createdAt: Date
}

@MainActor
private final class LifecycleActionDispatcher: AppActionPerforming {
    struct PerformedAction: Equatable {
        let id: AppActionID
        let source: AppActionSource
        let arguments: [String: String]?
    }

    let availableActions: [AppActionDefinition] = [
        AppActionDefinition(
            id: .createNode,
            title: "Create New Node",
            icon: "plus",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: false
        )
    ]
    private let executed: Bool
    private(set) var performed: [PerformedAction] = []

    init(executed: Bool = true) {
        self.executed = executed
    }

    func definition(for id: AppActionID) -> AppActionDefinition? {
        availableActions.first { $0.id == id }
    }

    func perform(
        _ id: AppActionID,
        source: AppActionSource,
        arguments: [String: String]?
    ) -> AppActionResult {
        performed.append(PerformedAction(id: id, source: source, arguments: arguments))
        return AppActionResult(
            actionID: id,
            title: definition(for: id)?.localizedTitle ?? id.rawValue,
            executed: executed,
            message: executed ? "Performed" : "Failed"
        )
    }
}
