//
//  caocapTests.swift
//  caocapTests
//
//  Created by الشيخ عزام on 20/04/2026.
//

import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct caocapTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func viewportDragTranslationUsesPhysicalDirections() {
        let viewport = ViewportState(offset: CGSize(width: 10, height: -20), scale: 1.0)

        viewport.handleDragTranslation(CGSize(width: 35, height: -15))
        #expect(viewport.offset == CGSize(width: 45, height: -35))

        viewport.handleDragEnded()
        viewport.handleDragTranslation(CGSize(width: -25, height: 40))
        #expect(viewport.offset == CGSize(width: 20, height: 5))
    }

    @Test func viewportDragEndedCommitsOffsetForNextGesture() {
        let viewport = ViewportState(offset: .zero, scale: 1.0)

        viewport.handleDragTranslation(CGSize(width: 50, height: 12))
        viewport.handleDragEnded()
        viewport.handleDragTranslation(CGSize(width: 10, height: -2))

        #expect(viewport.offset == CGSize(width: 60, height: 10))
        #expect(viewport.lastOffset == CGSize(width: 50, height: 12))
    }

    @Test func defaultProjectStartsWithStructuredSRS() throws {
        let srsNode = try #require(ProjectTemplateProvider.defaultNodes.first { $0.type == .srs })
        let text = try #require(srsNode.textContent)

        #expect(text.contains("# Intent"))
        #expect(text.contains("## Why It Matters"))
        #expect(text.contains("## Core Flow"))
        #expect(text.contains("## Acceptance Checks"))
        #expect(text.contains("CoCaptain has enough context"))
        #expect(srsNode.srsReadinessState == .needsClarification)
    }

    @Test func defaultProjectDoesNotAutoTriggerNodeAgents() throws {
        let codeNode = try #require(ProjectTemplateProvider.defaultNodes.first { $0.type == .code })
        #expect(codeNode.agentProfile.isAutoTriggerEnabled == false)
    }

    @Test func srsScaffoldPreservesDraftAndAddsMissingSections() {
        let draft = "# Intent\nBuild a calmer way to shape software requirements."
        let structuredText = SRSScaffold.structuredText(from: draft)

        #expect(structuredText.hasPrefix(draft))
        #expect(structuredText.contains("## People"))
        #expect(structuredText.contains("## Requirements"))
        #expect(structuredText.contains("## Constraints"))
    }

    @MainActor
    @Test func dispatcherAllowsExplicitlyAutonomousWorkspaceMutations() {
        let dispatcher = AppActionDispatcher()
        var createdTextNode = false

        dispatcher.configure(
            goHome: {},
            goBack: {},
            newProject: {},
            createNode: {},
            onCreateTextNode: { createdTextNode = true },
            onCreateCalculationNode: {},
            onCreateDisplayNode: {},
            onCreateNumberNode: {},
            onCreateTableNode: {},
            onCreateAiAgentNode: {},
            summonCoCaptain: {}
        )

        let result = dispatcher.perform(.createTextNode, source: .agentAutomatic)

        #expect(result.executed)
        #expect(createdTextNode)
    }

    @MainActor
    @Test func dispatcherBlocksNonAutonomousProjectCreationFromAgentAutomatic() {
        let dispatcher = AppActionDispatcher()
        var createdProject = false

        dispatcher.configure(
            goHome: {},
            goBack: {},
            newProject: { createdProject = true },
            createNode: {},
            onCreateCalculationNode: {},
            onCreateDisplayNode: {},
            onCreateNumberNode: {},
            onCreateTableNode: {},
            onCreateAiAgentNode: {},
            summonCoCaptain: {}
        )

        let result = dispatcher.perform(.newProject, source: .agentAutomatic)

        #expect(!result.executed)
        #expect(!createdProject)
    }

    @MainActor
    @Test func webBundleExportIncludesRunnableIndexAndSRSReadme() throws {
        let store = ProjectStore(
            fileName: "onboarding-export-test-\(UUID().uuidString).json",
            projectName: "Export Test",
            initialNodes: ProjectTemplateProvider.defaultNodes
        )

        let exportURL = try #require(ExportService.export(from: store, format: .webBundle(includeProjectContext: true)))
        defer { try? FileManager.default.removeItem(at: exportURL) }

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: exportURL.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(FileManager.default.fileExists(atPath: exportURL.appendingPathComponent("index.html").path))
        #expect(FileManager.default.fileExists(atPath: exportURL.appendingPathComponent("README.md").path))

        let readme = try String(contentsOf: exportURL.appendingPathComponent("README.md"), encoding: .utf8)
        #expect(readme.contains("## Software Requirements"))
        #expect(readme.contains("# Intent"))
    }
}
