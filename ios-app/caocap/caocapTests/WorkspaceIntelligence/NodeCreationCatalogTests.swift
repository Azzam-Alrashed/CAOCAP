import Foundation
import Testing
@testable import caocap

struct NodeCreationCatalogTests {

    @Test func catalogMatchesCodeQuery() {
        let catalog = NodeCreationCatalog()
        let results = catalog.search(query: "code")

        #expect(results.contains(where: { $0.id == .code }))
        #expect(!results.contains(where: { $0.id == .webView }))
    }

    @Test func catalogMatchesPreviewAlias() {
        let catalog = NodeCreationCatalog()
        let results = catalog.search(query: "preview")

        #expect(results.contains(where: { $0.id == .webView }))
    }

    @Test func catalogReturnsEmptyForBlankQuery() {
        let catalog = NodeCreationCatalog()
        #expect(catalog.search(query: "   ").isEmpty)
    }
}
