import Foundation
import Testing
@testable import caocap

struct AnalysisTests {

    @Test func analyzerDoesNotSuggestAnythingForEmptyCanvas() throws {
        let suggestions = ProjectAnalyzer().analyze(nodes: [])
        #expect(suggestions.isEmpty)
    }

    @Test func analyzerDoesNotSuggestHTMLOrSRSWork() {
        let nodes = [
            SpatialNode(type: .standard, position: .zero, title: "Card")
        ]
        let suggestions = ProjectAnalyzer().analyze(nodes: nodes)
        #expect(suggestions.isEmpty)
    }

    @Test func analyzerFlagsPendingNodeReviews() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bundle = ReviewBundleItem(
            items: [
                PendingReviewItem(
                    targetLabel: "Create node",
                    summary: "Pending",
                    preview: "preview",
                    source: .appAction(.createNode, ["title": "New"])
                )
            ]
        )
        let record = CoCaptainReviewLifecycle.Record(bundle: bundle)
        var agentState = NodeAgentState()
        agentState.pendingReviewBundlesData = [try encoder.encode(record)]

        let nodes = [
            SpatialNode(
                type: .standard,
                position: .zero,
                title: "Card",
                agentState: agentState
            )
        ]

        let suggestions = ProjectAnalyzer().analyze(nodes: nodes)
        #expect(suggestions.contains { $0.title == "Card has pending CoCaptain reviews" })
    }

    @MainActor
    @Test func viewModelDoesNotShowSuggestionsForEmptyCanvas() throws {
        let viewModel = CoCaptainViewModel()
        let store = ProjectStore(fileName: "test_project.json", projectName: "Test")

        #expect(viewModel.analysisItems.isEmpty)

        viewModel.store = store

        #expect(viewModel.analysisItems.isEmpty)
    }
}
