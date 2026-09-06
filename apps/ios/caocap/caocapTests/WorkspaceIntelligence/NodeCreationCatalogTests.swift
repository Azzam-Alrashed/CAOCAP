import Foundation
import Testing
@testable import caocap

struct NodeCreationCatalogTests {

    @Test func catalogMatchesCardQuery() {
        let catalog = NodeCreationCatalog()
        let results = catalog.search(query: "card")

        #expect(results.contains(where: { $0.id == .standard }))
        #expect(!results.contains(where: { $0.id == .subCanvas }))
    }

    @Test func catalogMatchesNodeAlias() {
        let catalog = NodeCreationCatalog()
        let results = catalog.search(query: "node")

        #expect(results.contains(where: { $0.id == .standard }))
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
