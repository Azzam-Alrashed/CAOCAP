import Testing
import Foundation
@testable import caocap

struct ProjectTemplateProviderTests {
    
    @Test func templateEnumCasesHaveValidProperties() {
        for template in ProjectTemplate.allCases {
            #expect(!template.id.isEmpty)
            #expect(!template.displayName.isEmpty)
            #expect(!template.description.isEmpty)
            #expect(!template.icon.isEmpty)
        }
    }
    
    @Test func nodesForHelloWorldTemplate() {
        let nodes = ProjectTemplateProvider.nodes(for: .helloWorld)
        #expect(nodes.count == 3)
        #expect(nodes.contains(where: { $0.type == .srs }))
        #expect(nodes.contains(where: { $0.type == .code }))
        #expect(nodes.contains(where: { $0.type == .webView }))
    }
}
