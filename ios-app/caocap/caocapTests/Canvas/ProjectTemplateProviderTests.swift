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
    
    @Test func nodesForReactiveCalculatorTemplate() {
        let nodes = ProjectTemplateProvider.nodes(for: .reactiveCalculator)
        #expect(nodes.count == 4)
        #expect(nodes.filter({ $0.type == .number }).count == 2)
        #expect(nodes.contains(where: { $0.type == .calculation }))
        #expect(nodes.contains(where: { $0.type == .display }))
        
        // Verify connections
        let calcNode = nodes.first(where: { $0.type == .calculation })!
        #expect(calcNode.operation == .subtract)
        #expect(calcNode.inputNodeIds?.count == 2)
    }
    
    @Test func nodesForBusinessAnalyticsTemplate() {
        let nodes = ProjectTemplateProvider.nodes(for: .businessAnalytics)
        #expect(nodes.count == 2)
        #expect(nodes.contains(where: { $0.type == .table }))
        #expect(nodes.contains(where: { $0.type == .chart }))
        
        let chartNode = nodes.first(where: { $0.type == .chart })!
        #expect(chartNode.chartStyle == .bar)
        #expect(chartNode.inputNodeIds?.count == 1)
    }
    
    @Test func nodesForAiPoetTemplate() {
        let nodes = ProjectTemplateProvider.nodes(for: .aiPoet)
        #expect(nodes.count == 2)
        #expect(nodes.contains(where: { $0.type == .text }))
        #expect(nodes.contains(where: { $0.type == .aiAgent }))
        
        let agentNode = nodes.first(where: { $0.type == .aiAgent })!
        #expect(agentNode.promptTemplate?.contains("{{Topic Input}}") == true)
        #expect(agentNode.inputNodeIds?.count == 1)
    }
}
