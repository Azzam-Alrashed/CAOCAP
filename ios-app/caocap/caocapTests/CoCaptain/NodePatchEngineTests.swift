import Foundation
import Testing
@testable import caocap

struct NodePatchEngineTests {
    @Test func applyResolvesLooseTargetOnDefaultCode() throws {
        let engine = NodePatchEngine()
        let result = try engine.apply(
            operations: [
                NodePatchOperation(type: .replaceExact, target: "hello world", content: "hello azzam")
            ],
            to: ProjectTemplateProvider.defaultCode
        )

        #expect(result.contains("<h1>hello azzam</h1>"))
    }

    @Test func applyResolvesExactTarget() throws {
        let engine = NodePatchEngine()
        let result = try engine.apply(
            operations: [
                NodePatchOperation(type: .replaceExact, target: "Hello World!", content: "Hello CAOCAP")
            ],
            to: "<html><body><h1>Hello World!</h1></body></html>"
        )

        #expect(result.contains("Hello CAOCAP"))
    }

    @Test func applyConflictsWhenTargetIsAmbiguous() {
        let engine = NodePatchEngine()

        #expect(throws: NodePatchError.self) {
            try engine.apply(
                operations: [
                    NodePatchOperation(type: .replaceExact, target: "hello", content: "bye")
                ],
                to: "<p>hello</p><p>hello</p>"
            )
        }
    }

    @Test func applyResolvingTargetsStagesCanonicalReplaceAll() throws {
        let engine = NodePatchEngine()
        let resolved = try engine.applyResolvingTargets(
            operations: [
                NodePatchOperation(type: .replaceExact, target: "hello world", content: "hello azzam")
            ],
            to: ProjectTemplateProvider.defaultCode
        )

        #expect(resolved.canonicalOperations == [
            NodePatchOperation(type: .replaceAll, content: resolved.resultText)
        ])
        #expect(resolved.resultText.contains("hello azzam"))
    }

    @MainActor
    @Test func previewResolvingStagesCanonicalReplaceAll() throws {
        let store = ProjectStore(
            fileName: "patch-preview-\(UUID().uuidString).json",
            projectName: "Tutorial",
            initialNodes: [TutorialCanvasProvider.practiceMiniAppNode]
        )
        let engine = NodePatchEngine()

        let resolved = try engine.previewResolving(
            role: .miniApp,
            section: .code,
            operations: [
                NodePatchOperation(type: .replaceExact, target: "hello world", content: "hello azzam")
            ],
            in: store
        )

        #expect(resolved.canonicalOperations == [
            NodePatchOperation(type: .replaceAll, content: resolved.preview.resultText)
        ])
        #expect(resolved.preview.resultText.contains("hello azzam"))
    }
}
