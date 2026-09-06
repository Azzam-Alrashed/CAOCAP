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

    @Test func applyOffersCandidatesWhenTargetIsAmbiguous() throws {
        let engine = NodePatchEngine()

        do {
            _ = try engine.apply(
                operations: [
                    NodePatchOperation(type: .replaceExact, target: "hello", content: "bye")
                ],
                to: "<p>hello</p><p>hello</p>"
            )
            Issue.record("Expected an ambiguous target error")
        } catch let NodePatchError.ambiguous(target, candidates) {
            #expect(target == "hello")
            #expect(candidates.count == 2)
        }
    }

    @Test func titleAliasResolvesToHeadingNotTitleTag() throws {
        let engine = NodePatchEngine()
        let result = try engine.apply(
            operations: [
                NodePatchOperation(type: .replaceExact, target: "title", content: "hi azzam")
            ],
            to: ProjectTemplateProvider.defaultCode
        )

        #expect(result.contains("<h1>hi azzam</h1>"))
        #expect(result.contains("<title>My App</title>"))
    }

    @Test func headlineAliasResolvesToHeading() throws {
        let engine = NodePatchEngine()
        let result = try engine.apply(
            operations: [
                NodePatchOperation(type: .replaceExact, target: "the headline", content: "Welcome!")
            ],
            to: "<html><head><title>My App</title></head><body><h1>Hello World!</h1></body></html>"
        )

        #expect(result.contains("<h1>Welcome!</h1>"))
        #expect(result.contains("<title>My App</title>"))
    }

    @Test func aliasWithTwoHeadingsOffersBothAsCandidates() {
        let engine = NodePatchEngine()
        let code = """
        <body>
        <h1>Welcome</h1>
        <h1>Scores</h1>
        </body>
        """

        do {
            _ = try engine.apply(
                operations: [
                    NodePatchOperation(type: .replaceExact, target: "heading", content: "Hi")
                ],
                to: code
            )
            Issue.record("Expected an ambiguous target error")
        } catch let NodePatchError.ambiguous(_, candidates) {
            #expect(candidates.count == 2)
            #expect(candidates.allSatisfy { $0.label.contains("the heading") })
        } catch {
            Issue.record("Expected NodePatchError.ambiguous, got \(error)")
        }
    }

    @Test func choosingCandidateResolvesAmbiguousTarget() throws {
        let engine = NodePatchEngine()
        let code = """
        <button>Save</button>
        <button>Save now</button>
        """

        var caught: [PatchMatchCandidate] = []
        do {
            _ = try engine.apply(
                operations: [
                    NodePatchOperation(type: .replaceExact, target: "Save", content: "Store")
                ],
                to: code
            )
            Issue.record("Expected an ambiguous target error")
        } catch let NodePatchError.ambiguous(_, candidates) {
            caught = candidates
        }

        let second = try #require(caught.last)
        let resolved = try engine.applyResolvingTargets(
            operations: [
                NodePatchOperation(type: .replaceExact, target: "Save", content: "Store")
            ],
            to: code,
            choosing: second
        )

        #expect(resolved.resultText.contains("<button>Save</button>"))
        #expect(resolved.resultText.contains("<button>Store now</button>"))
    }

    @Test func missingTargetStillConflicts() {
        let engine = NodePatchEngine()

        do {
            _ = try engine.apply(
                operations: [
                    NodePatchOperation(type: .replaceExact, target: "zebra unicorn", content: "x")
                ],
                to: "<h1>Hello World!</h1>"
            )
            Issue.record("Expected a conflict error")
        } catch NodePatchError.conflict {
            // Expected: no candidates to offer, friendly conflict message.
        } catch {
            Issue.record("Expected NodePatchError.conflict, got \(error)")
        }
    }

    @Test func nearMatchOffersDidYouMeanCandidates() {
        let engine = NodePatchEngine()

        do {
            _ = try engine.apply(
                operations: [
                    NodePatchOperation(type: .replaceExact, target: "hello world friends", content: "hi")
                ],
                to: "<h1>Hello World!</h1>\n<p>Something else</p>"
            )
            Issue.record("Expected an ambiguous (near-match) error")
        } catch let NodePatchError.ambiguous(_, candidates) {
            #expect(candidates.count == 1)
        } catch {
            Issue.record("Expected NodePatchError.ambiguous, got \(error)")
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
            initialNodes: [
                SpatialNode(
                    type: .miniApp,
                    position: .zero,
                    title: "Mini-App",
                    miniApp: MiniAppState(codeText: "hello world")
                )
            ]
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
