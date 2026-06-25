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
        #expect(nodes.count == 1)
        let miniApp = nodes.first
        #expect(miniApp?.type == .miniApp)
        #expect(miniApp?.miniApp?.srsText.contains("# Intent") == true)
        #expect(miniApp?.miniApp?.codeText.contains("Hello World!") == true)
    }
}
