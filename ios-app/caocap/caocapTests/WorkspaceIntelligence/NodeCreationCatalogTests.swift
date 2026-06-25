import Foundation
import Testing
@testable import caocap

struct NodeCreationCatalogTests {

    @Test func catalogMatchesCodeQueryWithMiniApp() {
        let catalog = NodeCreationCatalog()
        let results = catalog.search(query: "code")

        #expect(results.contains(where: { $0.id == .miniApp }))
        #expect(!results.contains(where: { $0.id == .subCanvas }))
    }

    @Test func catalogMatchesPreviewAlias() {
        let catalog = NodeCreationCatalog()
        let results = catalog.search(query: "preview")

        #expect(results.contains(where: { $0.id == .miniApp }))
    }

    @Test func catalogReturnsEmptyForBlankQuery() {
        let catalog = NodeCreationCatalog()
        #expect(catalog.search(query: "   ").isEmpty)
    }

    @Test func catalogDoesNotMatchBackInsideBackendKeyword() {
        let catalog = NodeCreationCatalog()
        let results = catalog.search(query: "back")

        #expect(results.isEmpty)
    }
}
