import Foundation
import Testing
@testable import caocap

struct AnalysisTests {

    @Test func analyzerIdentifiesEmptyCode() throws {
        let nodes = [
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: ""))
        ]
        let analyzer = ProjectAnalyzer()
        let suggestions = analyzer.analyze(nodes: nodes)
        
        #expect(suggestions.contains { $0.title == "Mini-App code is empty" })
    }

    @Test func analyzerDoesNotSuggestAnythingForEmptyCanvas() throws {
        let nodes: [SpatialNode] = []
        let analyzer = ProjectAnalyzer()
        let suggestions = analyzer.analyze(nodes: nodes)
        
        #expect(suggestions.isEmpty)
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
