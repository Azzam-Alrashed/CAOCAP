import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct CommandPaletteNavigationPriorityTests {
    @Test func queriedNavigationActionsAppearBeforeMatchingCanvasNodes() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = [
            action(.openSettings, title: "Open Settings"),
            action(.goRoot, title: "Go to Root"),
            action(.goBack, title: "Go Back")
        ]
        viewModel.nodes = [
            SpatialNode(position: .zero, title: "Go Back Notes")
        ]
        viewModel.query = "go"

        #expect(viewModel.filteredActions.map(\.id) == [.goBack, .goRoot])
        #expect(viewModel.prioritizedNavigationActionCount == 2)
        #expect(viewModel.selectionIndex(forActionAt: 0) == 0)
        #expect(viewModel.selectionIndex(forActionAt: 1) == 1)
        #expect(viewModel.selectionIndex(forNodeResultAt: 0) == 2)
    }

    @Test func confirmingFirstQueriedResultExecutesNavigationInsteadOfFlyingToNode() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = [
            action(.goBack, title: "Go Back")
        ]
        viewModel.nodes = [
            SpatialNode(position: .zero, title: "Backlog")
        ]
        viewModel.query = "back"

        var executedAction: AppActionID?
        var flownNodeID: UUID?
        viewModel.onExecute = { executedAction = $0 }
        viewModel.onFlyToNode = { flownNodeID = $0 }

        viewModel.confirmSelection()

        #expect(executedAction == .goBack)
        #expect(flownNodeID == nil)
    }

    private func action(_ id: AppActionID, title: String) -> AppActionDefinition {
        AppActionDefinition(
            id: id,
            title: title,
            icon: "circle",
            category: .navigation,
            isMutating: false,
            allowsAutonomousExecution: true
        )
    }
}
