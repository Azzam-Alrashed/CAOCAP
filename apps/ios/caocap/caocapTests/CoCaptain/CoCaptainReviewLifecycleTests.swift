import Foundation
import SwiftUI
import Testing
@testable import caocap

@MainActor
struct CoCaptainReviewLifecycleTests {
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

    @Test func rejectAllRejectsPendingAppActions() throws {
        let store = makeStore()
        let dispatcher = LifecycleActionDispatcher()
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: dispatcher)
        let record = try #require(
            session.stage(
                CoCaptainReviewLifecycle.Draft(
                    pendingActions: [
                        CoCaptainAgentAction(actionID: AppActionID.createNode.rawValue)
                    ]
                )
            )
        )

        let transition = try session.resolve(.rejectAll, in: record.id).get()

        #expect(transition.record.bundle.items.allSatisfy { $0.status == .rejected })
        #expect(transition.effects.count == 1)
        #expect(dispatcher.performed.isEmpty)
    }

    @Test func callerFailuresDoNotChangeRecord() throws {
        let store = makeStore()
        let session = CoCaptainReviewLifecycle()
            .session(scope: .project, store: store, dispatcher: LifecycleActionDispatcher())
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

    @Test func nodePersistenceKeepsPendingActionsAndRemovesTerminalRecords() throws {
        let store = makeStore()
        let nodeID = store.nodes[0].id
        let lifecycle = CoCaptainReviewLifecycle()
        let session = lifecycle.session(
            scope: .node(nodeID),
            store: store,
            dispatcher: LifecycleActionDispatcher()
        )
        let record = try #require(
            session.stage(
                CoCaptainReviewLifecycle.Draft(
                    pendingActions: [
                        CoCaptainAgentAction(actionID: AppActionID.createNode.rawValue)
                    ]
                )
            )
        )

        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.count == 1)
        #expect(
            lifecycle.session(scope: .node(nodeID), store: store, dispatcher: nil)
                .records.first?.bundle.items.first?.status == .pending
        )

        let itemID = try #require(record.bundle.items.first?.id)
        _ = try session.resolve(.reject(itemID: itemID), in: record.id).get()
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.isEmpty == true)
        #expect(session.records.first?.bundle.items.first?.status == .rejected)
    }

    @Test func projectSessionsAreEphemeralAndClearIsScopeAware() throws {
        let store = makeStore()
        let nodeID = store.nodes[0].id
        let lifecycle = CoCaptainReviewLifecycle()
        let projectSession = lifecycle.session(
            scope: .project,
            store: store,
            dispatcher: LifecycleActionDispatcher()
        )
        _ = projectSession.stage(
            CoCaptainReviewLifecycle.Draft(
                pendingActions: [
                    CoCaptainAgentAction(actionID: AppActionID.createNode.rawValue)
                ]
            )
        )

        #expect(projectSession.records.count == 1)
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.isEmpty == true)
        #expect(
            lifecycle.session(scope: .project, store: store, dispatcher: nil)
                .records.isEmpty
        )

        let nodeSession = lifecycle.session(
            scope: .node(nodeID),
            store: store,
            dispatcher: LifecycleActionDispatcher()
        )
        _ = nodeSession.stage(
            CoCaptainReviewLifecycle.Draft(
                pendingActions: [
                    CoCaptainAgentAction(actionID: AppActionID.createNode.rawValue)
                ]
            )
        )
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.count == 1)
        nodeSession.clear()
        #expect(nodeSession.records.isEmpty)
        #expect(store.nodes.first?.agentState.pendingReviewBundlesData.isEmpty == true)
    }

    @Test func restoreRemovesCorruptPersistenceWithoutAnotherNormalizationTrigger() throws {
        let store = makeStore()
        let nodeID = store.nodes[0].id
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
                    type: .standard,
                    position: .zero,
                    title: "Card"
                )
            ]
        )
    }
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
