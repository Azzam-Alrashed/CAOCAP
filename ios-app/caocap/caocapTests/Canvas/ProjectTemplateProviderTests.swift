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
    
    @Test func nodesForMakeItRememberTemplate() {
        let nodes = ProjectTemplateProvider.nodes(for: .helloWorld)
        #expect(nodes.count == 1)
        let miniApp = nodes.first
        #expect(miniApp?.type == .miniApp)
        #expect(ProjectTemplate.helloWorld.displayName == "Make It Remember")
        #expect(miniApp?.title == "Make It Remember")
        #expect(miniApp?.subtitle?.contains("remember") == true)
        #expect(miniApp?.miniApp?.srsText.contains("# Intent") == true)
        #expect(miniApp?.miniApp?.srsText.contains("Make this button remember") == true)
        #expect(miniApp?.miniApp?.srsText.contains("state") == true)
        #expect(miniApp?.miniApp?.codeText.contains("Make It Remember") == true)
        #expect(miniApp?.miniApp?.codeText.contains("tapCount") == true)
        #expect(miniApp?.miniApp?.codeText.contains("taps remembered") == true)
        #expect(miniApp?.agentProfile.roleName == "Mini-App Mentor")
    }
}
