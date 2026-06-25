import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct CoCaptainAgentTests {
    @MainActor
    @Test func projectContextIncludesCanonicalNodesAndExcludesCompiledPreview() throws {
        let store = makeStore()
        store.nodes.append(
            SpatialNode(
                type: .webView,
                position: .zero,
                title: "Live Preview",
                theme: .blue,
                htmlContent: "<html>compiled</html>"
            )
        )

        let context = ProjectContextBuilder().buildPromptContext(from: store)

        #expect(context.contains("Project Name: Test Project"))
        #expect(context.contains("SRS:"))
        #expect(context.contains("Code:"))
        #expect(context.contains("Build a landing page"))
        #expect(!context.contains("compiled"))
    }

    @MainActor
    @Test func projectContextIncludesBlankCanvasHintWhenNoCodeNodesExist() throws {
        let store = ProjectStore(
            fileName: "blank-canvas-test-\(UUID().uuidString).json",
            projectName: "Blank Project",
            initialNodes: [
                SpatialNode(
                    type: .srs,
                    position: CGPoint(x: 0, y: 0),
                    title: "Software Requirements (SRS)",
                    theme: .purple,
                    textContent: "Just starting out."
                )
            ]
        )

        let context = ProjectContextBuilder().buildPromptContext(from: store)

        #expect(context.contains("Implementation State: Blank Canvas (No code nodes exist yet)"))
    }

    @MainActor
    @Test func nodeContextIncludesSelectedNodeAndLinkedNeighbors() throws {
        let codeID = UUID()
        let srsID = UUID()
        let unrelatedID = UUID()
        let store = ProjectStore(
            fileName: "node-context-\(UUID().uuidString).json",
            projectName: "Node Context",
            initialNodes: [
                SpatialNode(id: srsID, type: .srs, position: .zero, title: "Software Requirements (SRS)", connectedNodeIds: [codeID], textContent: "Selected SRS content"),
                SpatialNode(id: codeID, type: .code, position: .zero, title: "Code", textContent: "<h1>Linked code</h1>"),
                SpatialNode(id: unrelatedID, type: .code, position: .zero, title: "Unrelated", textContent: "Do not leak full unrelated content")
            ]
        )

        let context = ProjectContextBuilder().buildNodePromptContext(from: store, nodeID: srsID)

        #expect(context.contains("Selected Node ID: \(srsID.uuidString)"))
        #expect(context.contains("Selected Node Content:\nSelected SRS content"))
        #expect(context.contains("Linked Neighbor Nodes:"))
        #expect(context.contains("<h1>Linked code</h1>"))
        #expect(context.contains("Unrelated [code] id: \(unrelatedID.uuidString)"))
        #expect(!context.contains("Do not leak full unrelated content"))
    }

    @Test func parserExtractsNodeIDTargetedNodeEdit() throws {
        let nodeID = UUID()
        let parser = CoCaptainAgentParser()
        let response =
            """
            Updating this node.

            <cocaptain_actions>
              <assistant_message>Prepared a targeted edit.</assistant_message>
              <node_edits>
                <node_edit nodeId="\(nodeID.uuidString)" role="code" summary="Target exact code node.">
                  <operation type="replace_all">
                    <content><![CDATA[<h1>Targeted</h1>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.payload?.nodeEdits.first?.nodeID == nodeID)
        #expect(parsed.payload?.nodeEdits.first?.role == .code)
    }

    @MainActor
    @Test func nodePatchEngineTargetsNodeIDBeforeRoleFallback() throws {
        let targetID = UUID()
        let otherID = UUID()
        let store = ProjectStore(
            fileName: "node-patch-\(UUID().uuidString).json",
            initialNodes: [
                SpatialNode(id: otherID, type: .code, position: .zero, title: "Code", textContent: "wrong"),
                SpatialNode(id: targetID, type: .code, position: .zero, title: "Custom Code", textContent: "right")
            ]
        )

        let preview = try NodePatchEngine().preview(
            nodeID: targetID,
            role: .code,
            operations: [NodePatchOperation(type: .replaceAll, content: "updated")],
            in: store
        )

        #expect(preview.nodeID == targetID)
        #expect(preview.originalText == "right")
        #expect(preview.resultText == "updated")
    }

    @MainActor
    @Test func nodeAgentMessagesPersistOnNode() {
        let store = makeStore()
        let node = store.nodes.first(where: { $0.role == .srs })!

        store.appendNodeAgentMessage(
            id: node.id,
            message: NodeAgentMessage(text: "Draft the intro", isUser: true),
            persist: false
        )

        let updatedNode = store.nodes.first(where: { $0.id == node.id })
        #expect(updatedNode?.agentState.messages.first?.text == "Draft the intro")
        #expect(updatedNode?.agentState.messages.first?.isUser == true)
    }

    @Test func nodePatchEngineAppliesOrderedOperations() throws {
        let engine = NodePatchEngine()
        let result = try engine.apply(
            operations: [
                NodePatchOperation(type: .replaceExact, target: "Hello", content: "Welcome"),
                NodePatchOperation(type: .append, content: "\n<footer>Done</footer>")
            ],
            to: "<h1>Hello</h1>"
        )

        #expect(result.contains("Welcome"))
        #expect(result.contains("<footer>Done</footer>"))
    }

    @Test func nodePatchEngineCanReplaceWholeNodeContent() throws {
        let engine = NodePatchEngine()
        let result = try engine.apply(
            operations: [
                NodePatchOperation(type: .replaceAll, content: "<main>New game shell</main>")
            ],
            to: "<h1>Old page</h1>"
        )

        #expect(result == "<main>New game shell</main>")
    }

    @Test func nodePatchEngineThrowsWhenAnchorMissing() throws {
        let engine = NodePatchEngine()

        #expect(throws: NodePatchError.self) {
            try engine.apply(
                operations: [NodePatchOperation(type: .insertAfterExact, target: "missing", content: "x")],
                to: "<h1>Hello</h1>"
            )
        }
    }

    @Test func nodeRoleInferenceRecognizesCanonicalTemplateNodes() {
        #expect(SpatialNode(type: .srs, position: .zero, title: "Software Requirements (SRS)").role == .srs)
        #expect(SpatialNode(type: .code, position: .zero, title: "Code").role == .code)
        #expect(SpatialNode(type: .code, position: .zero, title: "HTML").role == .code)
        #expect(SpatialNode(type: .code, position: .zero, title: "CSS").role == .code)
        #expect(SpatialNode(type: .code, position: .zero, title: "JavaScript").role == .code)
        #expect(SpatialNode(type: .webView, position: .zero, title: "Live Preview").role == .livePreview)
        #expect(SpatialNode(type: .code, position: .zero, title: "New Logic").role == .code)
        #expect(SpatialNode(position: .zero, title: "New Logic").role == .custom)
        #expect(SpatialNode(type: .firebase, position: .zero, title: "Firebase").role == .firebase)
    }

    @Test func livePreviewCompilerInjectsFirebaseWhenConfigNodePresent() throws {
        let codeNode = SpatialNode(
            type: .code,
            position: .zero,
            title: "Code",
            theme: .orange,
            textContent: "<html><head></head><body><p>x</p></body></html>"
        )
        let previewNode = SpatialNode(
            type: .webView,
            position: .zero,
            title: "Live Preview",
            theme: .blue
        )
        let firebaseNode = SpatialNode(
            type: .firebase,
            position: .zero,
            title: "Firebase",
            theme: .orange,
            textContent: #"{"apiKey":"testKey","authDomain":"t.firebaseapp.com","projectId":"tid","storageBucket":"t.appspot.com","messagingSenderId":"1","appId":"1:1:web:abc"}"#
        )
        let compilation = try #require(LivePreviewCompiler().compile(nodes: [previewNode, codeNode, firebaseNode]))
        #expect(compilation.html.contains("__caocap_fb_b64"))
        #expect(compilation.html.contains("firebase-app-compat.js"))
    }

    @Test func livePreviewCompilerUsesFirstValidFirebaseNodeWhenEarlierIsPlaceholder() throws {
        let htmlNode = SpatialNode(
            type: .code,
            position: .zero,
            title: "HTML",
            theme: .orange,
            textContent: "<html><head></head><body></body></html>"
        )
        let previewNode = SpatialNode(
            type: .webView,
            position: .zero,
            title: "Live Preview",
            theme: .blue
        )
        let stubFirebase = SpatialNode(
            type: .firebase,
            position: .zero,
            title: "Firebase Stub",
            theme: .orange,
            textContent: FirebasePreviewBootstrap.placeholderConfigJSON()
        )
        let realFirebase = SpatialNode(
            type: .firebase,
            position: .zero,
            title: "Firebase Real",
            theme: .orange,
            textContent: #"{"apiKey":"realWebKey","authDomain":"x.firebaseapp.com","projectId":"myrealpid","storageBucket":"x.appspot.com","messagingSenderId":"1","appId":"1:1:web:abc"}"#
        )
        let compilation = try #require(
            LivePreviewCompiler().compile(nodes: [previewNode, htmlNode, stubFirebase, realFirebase])
        )
        #expect(compilation.html.contains("__caocap_fb_b64"))
        #expect(compilation.html.contains("firebase-app-compat.js"))
    }

    @Test func livePreviewCompilerUsesFirstCodeNodeWhenMultipleExist() throws {
        let nodes = [
            SpatialNode(type: .webView, position: .zero, title: "Live Preview"),
            SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<html><body><h1>Combined</h1></body></html>"),
            SpatialNode(type: .code, position: .zero, title: "Other Code", textContent: "<h1>Ignored</h1>")
        ]

        let compilation = try #require(LivePreviewCompiler().compile(nodes: nodes))

        #expect(compilation.html.contains("Combined"))
        #expect(!compilation.html.contains("Ignored"))
    }

    @Test func livePreviewCompilerInjectsFirebaseIntoCombinedCodeNode() throws {
        let nodes = [
            SpatialNode(type: .webView, position: .zero, title: "Live Preview"),
            SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<html><head></head><body><h1>Combined</h1></body></html>"),
            SpatialNode(
                type: .firebase,
                position: .zero,
                title: "Firebase",
                textContent: #"{"apiKey":"testKey","authDomain":"t.firebaseapp.com","projectId":"tid","storageBucket":"t.appspot.com","messagingSenderId":"1","appId":"1:1:web:abc"}"#
            )
        ]

        let compilation = try #require(LivePreviewCompiler().compile(nodes: nodes))

        #expect(compilation.html.contains("__caocap_fb_b64"))
        #expect(compilation.html.contains("firebase-app-compat.js"))
        #expect(compilation.html.contains("data-caocap-fb-diag"))
    }

    @Test func livePreviewCompilerInjectsViewportMetaWhenMissing() throws {
        let compiler = LivePreviewCompiler()
        
        // Scenario 1: Already has viewport tag (double quotes)
        let hasViewportDouble = [
            SpatialNode(type: .webView, position: .zero, title: "Live Preview"),
            SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<html><head><meta name=\"viewport\" content=\"width=device-width\"></head><body></body></html>")
        ]
        let compilationDouble = try #require(compiler.compile(nodes: hasViewportDouble))
        #expect(compilationDouble.html.components(separatedBy: "viewport").count == 2)
        
        // Scenario 2: Already has viewport tag (single quotes)
        let hasViewportSingle = [
            SpatialNode(type: .webView, position: .zero, title: "Live Preview"),
            SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<html><head><meta name='viewport' content='width=device-width'></head><body></body></html>")
        ]
        let compilationSingle = try #require(compiler.compile(nodes: hasViewportSingle))
        #expect(compilationSingle.html.components(separatedBy: "viewport").count == 2)
        
        // Scenario 3: Has <head>, missing viewport
        let missingViewportWithHead = [
            SpatialNode(type: .webView, position: .zero, title: "Live Preview"),
            SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<html><head><title>Test</title></head><body><h1>Hello</h1></body></html>")
        ]
        let compilationWithHead = try #require(compiler.compile(nodes: missingViewportWithHead))
        #expect(compilationWithHead.html.contains("viewport"))
        #expect(compilationWithHead.html.contains("<head>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"))
        
        // Scenario 4: Has <html>, missing <head>
        let missingViewportWithHtml = [
            SpatialNode(type: .webView, position: .zero, title: "Live Preview"),
            SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<html><body><h1>Hello</h1></body></html>")
        ]
        let compilationWithHtml = try #require(compiler.compile(nodes: missingViewportWithHtml))
        #expect(compilationWithHtml.html.contains("viewport"))
        #expect(compilationWithHtml.html.contains("<head>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n</head>"))
        
        // Scenario 5: Missing both <head> and <html>
        let missingViewportFragment = [
            SpatialNode(type: .webView, position: .zero, title: "Live Preview"),
            SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<h1>Hello World</h1>")
        ]
        let compilationFragment = try #require(compiler.compile(nodes: missingViewportFragment))
        #expect(compilationFragment.html.contains("viewport"))
        #expect(compilationFragment.html.contains("<!DOCTYPE html>"))
        #expect(compilationFragment.html.contains("<html><head>"))
    }

    @Test func livePreviewCompilerRequiresPreviewAndCodeNodes() {
        let compiler = LivePreviewCompiler()
        let codeOnly = [SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<h1>Hello</h1>")]
        let previewOnly = [SpatialNode(type: .webView, position: .zero, title: "Live Preview")]

        #expect(compiler.compile(nodes: codeOnly) == nil)
        #expect(compiler.compile(nodes: previewOnly) == nil)
    }

    @Test func chatBubbleMarkdownPreservesVisibleContent() {
        let bubble = ChatBubbleItem(
            text: """
            **Next steps**

            - Tighten layout
            - Improve contrast
            """,
            isUser: false
        )

        let renderedText = String(bubble.markdownText.characters)

        #expect(renderedText.contains("Next steps"))
        #expect(renderedText.contains("Tighten layout"))
        #expect(renderedText.contains("Improve contrast"))
    }

    @MainActor
    @Test func commandIntentResolverMatchesEnglishProjectCommands() throws {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("create a project", availableActions: actions) == .newProject)
        #expect(resolver.resolve("please create a project", availableActions: actions) == .newProject)
        #expect(resolver.resolve("new project", availableActions: actions) == .newProject)
        #expect(resolver.resolve("open settings", availableActions: actions) == .openSettings)
        #expect(resolver.resolve("make a root page", availableActions: actions) == nil)
        #expect(resolver.resolve("do not create a project", availableActions: actions) == nil)
    }

    @MainActor
    @Test func commandIntentResolverMatchesArabicProjectCommands() throws {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("أنشئ مشروع جديد", availableActions: actions) == .newProject)
        #expect(resolver.resolve("لو سمحت أنشئ مشروع جديد", availableActions: actions) == .newProject)
        #expect(resolver.resolve("افتح الإعدادات", availableActions: actions) == .openSettings)
        #expect(resolver.resolve("اعرض المشاريع", availableActions: actions) == .openProjectExplorer)
        #expect(resolver.resolve("لا تنشئ مشروع جديد", availableActions: actions) == nil)
    }

    @MainActor
    @Test func commandPaletteSubmitsUnmatchedQueryAsPrompt() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = TestActionDispatcher().availableActions
        viewModel.query = "  make a tiny platformer  "

        var submittedPrompt: String?
        var executedAction: AppActionID?
        viewModel.onSubmitPrompt = { submittedPrompt = $0 }
        viewModel.onExecute = { executedAction = $0 }

        viewModel.confirmSelection()

        #expect(submittedPrompt == "make a tiny platformer")
        #expect(executedAction == nil)
        #expect(viewModel.isPresented == false)
    }

    @MainActor
    @Test func commandPalettePrefersListedCommandOverPrompt() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = TestActionDispatcher().availableActions
        viewModel.query = "settings"

        var submittedPrompt: String?
        var executedAction: AppActionID?
        viewModel.onSubmitPrompt = { submittedPrompt = $0 }
        viewModel.onExecute = { executedAction = $0 }

        viewModel.confirmSelection()

        #expect(executedAction == .openSettings)
        #expect(submittedPrompt == nil)
    }

    @MainActor
    @Test func commandPaletteIncludesCoCaptainPromptInNavigableIndices() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = TestActionDispatcher().availableActions
        
        // With a non-empty query, even if there are match options, CoCaptain prompt is included as final index.
        viewModel.query = "settings"
        
        let actionsCount = viewModel.filteredActions.count
        let totalCount = actionsCount + viewModel.nodeResults.count + 1
        
        // Move selection down to the last item (CoCaptain Prompt)
        for _ in 0..<actionsCount {
            viewModel.moveSelection(direction: .down)
        }
        
        #expect(viewModel.selectedIndex == actionsCount)
        
        var submittedPrompt: String?
        viewModel.onSubmitPrompt = { submittedPrompt = $0 }
        viewModel.confirmSelection()
        
        #expect(submittedPrompt == "settings")
    }

    @MainActor
    @Test func commandPaletteCanSelectPromptRowDirectly() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = TestActionDispatcher().availableActions
        viewModel.query = "settings"

        viewModel.selectPromptRowIfAvailable()

        let promptIndex = viewModel.filteredActions.count + viewModel.nodeResults.count
        #expect(viewModel.selectedIndex == promptIndex)
    }

    @MainActor
    @Test func commandPaletteArrowNavigationWraparound() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = TestActionDispatcher().availableActions
        viewModel.query = "settings"
        
        let expectedCount = viewModel.filteredActions.count + viewModel.nodeResults.count + 1
        
        // Initially at 0
        #expect(viewModel.selectedIndex == 0)
        
        // Move up -> wraps to last index
        viewModel.moveSelection(direction: .up)
        #expect(viewModel.selectedIndex == expectedCount - 1)
        
        // Move down -> wraps to 0
        viewModel.moveSelection(direction: .down)
        #expect(viewModel.selectedIndex == 0)
    }

    @MainActor
    @Test func commandPaletteClearingPromptDisablesPromptSubmissionAndResetsSelection() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = TestActionDispatcher().availableActions
        viewModel.query = "settings"

        let promptIndex = viewModel.filteredActions.count + viewModel.nodeResults.count
        while viewModel.selectedIndex != promptIndex {
            viewModel.moveSelection(direction: .down)
        }

        #expect(viewModel.canSubmitPrompt)
        #expect(viewModel.selectedIndex == promptIndex)

        viewModel.query = ""

        #expect(!viewModel.canSubmitPrompt)
        #expect(viewModel.selectedIndex == 0)
    }

    @Test func parserExtractsTrailingStructuredBlock() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            I can make that update.

            <cocaptain_actions>
              <assistant_message>I can make that update.</assistant_message>
              <safe_actions>
                <action id="go_root" />
              </safe_actions>
              <pending_actions></pending_actions>
              <node_edits></node_edits>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.preamble == "I can make that update.")
        #expect(parsed.visibleText == "I can make that update.")
        #expect(parsed.payload?.safeActions.count == 1)
        #expect(parsed.payload?.safeActions.first?.actionID == "go_root")
    }

    @Test func parserDetectsLoosePayloadWithoutWhitespace() throws {
        let parser = CoCaptainAgentParser()
        let response = "aesthetic.<cocaptain_actions><assistant_message>Implementing...</assistant_message></cocaptain_actions>"

        let parsed = parser.parse(response)
        #expect(parsed.preamble == "aesthetic.")
        #expect(parsed.payload?.assistantMessage == "Implementing...")
    }

    @Test func parserHandlesCurlyQuotesInLoosePayload() throws {
        let parser = CoCaptainAgentParser()
        // Some models send smart quotes like “assistantMessage”
        let response = "OK. { “assistantMessage”: “Hello” }"

        let parsed = parser.parse(response)
        #expect(parsed.preamble == "OK.")
        #expect(parsed.payload?.assistantMessage == "Hello")
    }

    @Test func parserHidesLooseTrailingActionXML() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            I can document that preference.

            <cocaptain_actions>
              <assistant_message>Documented the preference.</assistant_message>
              <node_edits>
                <node_edit role="srs" summary="Document color preference.">
                  <operation type="append">
                    <content><![CDATA[\nPrimary color: Slate Grey.]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.preamble == "I can document that preference.")
        #expect(parsed.payload?.nodeEdits.count == 1)
    }

    @Test func parserHidesIncompleteLooseTrailingActionXML() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            Working on it.

            <cocaptain_actions>
              <assistant_message>Still generating...
            """

        let parsed = parser.parse(response)

        // Should NOT show the XML even if it's not closed yet.
        #expect(parsed.preamble == "Working on it.")
        #expect(parsed.payload == nil)
    }

    @Test func chatBubbleMarkdownFallsBackToInlineSyntax() {
        let bubble = ChatBubbleItem(
            text: "Hello *world*",
            isUser: false
        )

        // This should always succeed and at least render the italics if possible.
        let renderedText = String(bubble.markdownText.characters)
        #expect(renderedText.contains("world"))
    }

    @Test func chatBubbleMarkdownStylesInlineCode() {
        let bubble = ChatBubbleItem(
            text: "Use `let x = 5` here",
            isUser: false
        )

        let attributed = bubble.markdownText
        // Check if the parser identifies inline code
        var foundInlineCode = false
        for run in attributed.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                foundInlineCode = true
            }
        }
        #expect(foundInlineCode)
    }

    @Test func parserHandlesMultiLineXML() throws {
        let parser = CoCaptainAgentParser()
        let response = """
        Updating:
        <cocaptain_actions>
          <assistant_message>Multi-line</assistant_message>
        </cocaptain_actions>
        """

        let parsed = parser.parse(response)
        #expect(parsed.visibleText == "Updating:")
        #expect(parsed.payload?.assistantMessage == "Multi-line")
    }

    @Test func parserFallsBackOnMissingClosingTag() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            I can help.

            <cocaptain_actions>
              <assistant_message>Incomplete
            """

        let parsed = parser.parse(response)

        #expect(parsed.payload == nil)
        #expect(parsed.preamble == "I can help.")
    }

    @Test func xmlAdapterProducesCoordinatorDirective() throws {
        let adapter = CoCaptainXMLAgentAdapter()
        let response =
            """
            Done.

            <cocaptain_actions>
              <assistant_message>Done.</assistant_message>
              <safe_actions><action id="go_root"/></safe_actions>
              <pending_actions></pending_actions>
              <node_edits></node_edits>
            </cocaptain_actions>
            """

        let directive = adapter.directive(from: response)

        #expect(directive.preamble == "Done.")
        #expect(directive.visibleText == "Done.")
        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.diagnostics.isEmpty)
        #expect(directive.source == .xml)
    }

    @Test func functionCallAdapterMapsSafeAction() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["actionId": "go_root", "executionMode": "safe"]
            )
        ])

        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.payload?.pendingActions.isEmpty == true)
        #expect(directive.diagnostics.isEmpty)
        #expect(directive.source == .functionCall)
    }

    @Test func functionCallAdapterMapsPendingAction() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["actionId": "create_node", "executionMode": "pending"]
            )
        ])

        #expect(directive.payload?.pendingActions.first?.actionID == "create_node")
        #expect(directive.payload?.safeActions.isEmpty == true)
        #expect(directive.diagnostics.isEmpty)
    }

    @Test func functionCallAdapterReportsMalformedCalls() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let missingAction = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["executionMode": "safe"]
            )
        ])
        let unknownFunction = adapter.directive(from: [
            CoCaptainAgentFunctionCall(name: "unknown_function", arguments: ["actionId": "go_root"])
        ])

        #expect(missingAction.payload == nil)
        #expect(missingAction.diagnostics.first?.contains("missing `actionId`") == true)
        #expect(unknownFunction.payload == nil)
        #expect(unknownFunction.diagnostics.first?.contains("Unknown function call") == true)
    }

    @Test func compositeAdapterMergesFunctionActionsAndFencedNodeEdits() throws {
        let adapter = CoCaptainCompositeAgentAdapter()
        let response =
            """
            I updated the project.

            <cocaptain_actions>
              <assistant_message>I updated the project.</assistant_message>
              <node_edits>
                <node_edit role="code" summary="Update Code.">
                  <operation type="replace_all">
                    <content><![CDATA[<h1>Fixed</h1>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """

        let directive = adapter.directive(
            from: response,
            functionCalls: [
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: ["actionId": "go_root", "executionMode": "safe"]
                )
            ]
        )

        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.payload?.nodeEdits.first?.role == .code)
        #expect(directive.source == .combined)
    }

    @MainActor
    @Test func coordinatorRetriesMalformedStructuredPayload() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                """
                I prepared an edit.

                <cocaptain_actions>
                  <assistant_message>Incomplete
                """,
                """
                I prepared a valid code edit.

                <cocaptain_actions>
                  <assistant_message>I prepared a valid code edit.</assistant_message>
                  <node_edits>
                    <node_edit role="code" summary="Update Code.">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Fixed</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update the code",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("satisfied the machine-readable CoCaptain action contract") == true)
        #expect(result.reviewBundle?.items.first?.status == .pending)
    }

    @MainActor
    @Test func coordinatorRetriesSRSRequestsWithoutNodeEdits() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                "I can help draft the requirements in chat.",
                """
                I prepared an SRS update.

                <cocaptain_actions>
                  <assistant_message>I prepared an SRS update.</assistant_message>
                  <node_edits>
                    <node_edit role="srs" summary="Draft the product requirements.">
                      <operation type="replace_all">
                        <content><![CDATA[# Software Requirements

                ## Goal
                Define a focused first version of the app.
                ]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "draft the SRS",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("documentation, requirements, spec, or SRS requests") == true)
        #expect(result.reviewBundle?.items.first?.targetLabel == "SRS")
        #expect(result.reviewBundle?.items.first?.status == .pending)
    }

    @MainActor
    @Test func coordinatorExecutesSafeActionsAndStagesPendingReviews() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response:
                """
                I moved us to root and prepared a code update.

                <cocaptain_actions>
                  <assistant_message>I moved us to root and prepared a code update.</assistant_message>
                  <safe_actions><action id="go_root"/></safe_actions>
                  <pending_actions><action id="create_node"/></pending_actions>
                  <node_edits>
                    <node_edit role="code" summary="Update the headline.">
                      <operation type="replace_exact">
                        <target>Hello World!</target>
                        <content><![CDATA[Agentic Hello!]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let store = makeStore()

        let result = try await coordinator.run(
            userMessage: "Do it",
            store: store,
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs == [.goRoot])
        #expect(result.executionSummary?.summary.contains("Go to Root") == true)
        #expect(result.reviewBundle?.items.count == 2)
    }

    @MainActor
    @Test func coordinatorUsesNodeScopedSessionAndStagesTargetedEdit() async throws {
        let dispatcher = TestActionDispatcher()
        let store = makeStore()
        let codeNode = try #require(store.nodes.first(where: { $0.role == .code }))
        let llm = TestLLMClient(
            response:
                """
                I prepared a code-node update.

                <cocaptain_actions>
                  <assistant_message>I prepared a code-node update.</assistant_message>
                  <node_edits>
                    <node_edit nodeId="\(codeNode.id.uuidString)" role="code" summary="Update targeted code node.">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Scoped</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "change this code node",
            store: store,
            dispatcher: dispatcher,
            scope: .node(codeNode.id)
        ) { _ in }

        #expect(llm.receivedScopes == [.node(codeNode.id)])
        #expect(result.reviewBundle?.items.first?.targetNodeID == codeNode.id)
        #expect(result.reviewBundle?.items.first?.targetLabel == "Code")
    }

    @MainActor
    @Test func coordinatorExecutesFunctionCalledSafeAction() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response: "Opening settings.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: ["actionId": "open_settings", "executionMode": "safe"]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "open settings",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs == [.openSettings])
        #expect(result.executionSummary?.summary.contains("Open Settings") == true)
    }

    @MainActor
    @Test func coordinatorStagesFunctionCalledPendingAction() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response: "I prepared the action for review.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: ["actionId": "create_node", "executionMode": "pending"]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create a node",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.reviewBundle?.items.first?.targetLabel == "Create New Node")
    }

    @MainActor
    @Test func coordinatorRetriesUnsafeFunctionCalledSafeAction() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                "I will create a node.",
                "I prepared the action for review."
            ],
            functionCalls: [
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["actionId": "create_node", "executionMode": "safe"]
                    )
                ],
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["actionId": "create_node", "executionMode": "pending"]
                    )
                ]
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create a node",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("move it to `pendingActions`") == true)
        #expect(result.reviewBundle?.items.first?.targetLabel == "Create New Node")
    }

    @MainActor
    @Test func coordinatorDoesNotPartiallyExecuteMalformedFunctionCall() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                "Opening settings.",
                "Opening settings."
            ],
            functionCalls: [
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["actionId": "open_settings", "executionMode": "safe"]
                    ),
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["executionMode": "safe"]
                    )
                ],
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                        arguments: ["actionId": "open_settings", "executionMode": "safe"]
                    )
                ]
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "open settings",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs == [.openSettings])
        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("missing `actionId`") == true)
    }

    @MainActor
    @Test func coordinatorDoesNotExecuteInvalidSafeActionBeforeRetry() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                """
                I will create a node.

                <cocaptain_actions>
                  <assistant_message>I will create a node.</assistant_message>
                  <safe_actions><action id="create_node"/></safe_actions>
                </cocaptain_actions>
                """,
                """
                I prepared the action for review.

                <cocaptain_actions>
                  <assistant_message>I prepared the action for review.</assistant_message>
                  <pending_actions><action id="create_node"/></pending_actions>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create a node",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("move it to `pendingActions`") == true)
        #expect(result.reviewBundle?.items.count == 1)
    }

    @MainActor
    @Test func coordinatorReturnsValidationReviewWhenRetryPayloadIsStillInvalid() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response:
                """
                I will use an unknown action.

                <cocaptain_actions>
                  <assistant_message>I will use an unknown action.</assistant_message>
                  <safe_actions><action id="launch_rocket"/></safe_actions>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create something",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.executionSummary == nil)
        #expect(result.reviewBundle?.items.first?.status == .conflicted)
        #expect(result.reviewBundle?.items.first?.preview.contains("Unknown safe action id `launch_rocket`.") == true)
    }

    @MainActor
    @Test func coordinatorRetriesEmptyNodeEditOperations() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                """
                I prepared an edit.

                <cocaptain_actions>
                  <assistant_message>I prepared an edit.</assistant_message>
                  <node_edits>
                    <node_edit role="code" summary="Update Code.">
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """,
                """
                I prepared a valid code edit.

                <cocaptain_actions>
                  <assistant_message>I prepared a valid code edit.</assistant_message>
                  <node_edits>
                    <node_edit role="code" summary="Update Code.">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Fixed</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update the code",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("must include at least one operation") == true)
        #expect(result.reviewBundle?.items.first?.status == .pending)
    }

    @MainActor
    @Test func applyReviewItemConflictsWhenNodeEditedAfterSuggestion() {
        let store = makeStore()
        let vm = CoCaptainViewModel()
        vm.store = store

        let codeNode = store.nodes.first(where: { $0.title == "Code" })!
        let baseText = codeNode.textContent ?? ""
        let bundleID = UUID()
        let itemID = UUID()

        vm.items.append(CoCaptainTimelineItem(
            id: bundleID,
            content: .reviewBundle(ReviewBundleItem(
                id: bundleID,
                items: [PendingReviewItem(
                    id: itemID,
                    targetLabel: "Code",
                    summary: "Update headline",
                    preview: "<h1>Agentic Hello!</h1>",
                    source: .nodeEdit(
                        role: .code,
                        operations: [NodePatchOperation(type: .replaceAll, content: "<h1>Agentic Hello!</h1>")],
                        baseText: baseText
                    )
                )]
            ))
        ))

        // User edits the Code node before clicking Apply — stale scenario.
        store.updateNodeTextContent(id: codeNode.id, text: "<h1>User wrote this instead</h1>", persist: false)
        vm.applyReviewItem(bundleID: bundleID, itemID: itemID)

        guard case .reviewBundle(let bundle) = vm.items.first(where: { $0.id == bundleID })?.content,
              let result = bundle.items.first(where: { $0.id == itemID }) else {
            Issue.record("Review bundle or item not found")
            return
        }

        #expect(result.status == .conflicted)
        #expect(result.conflictDescription?.contains("edited after") == true)
    }

    @MainActor
    @Test func applyReviewItemSucceedsWhenNodeUnchanged() {
        let store = makeStore()
        let vm = CoCaptainViewModel()
        vm.store = store

        let codeNode = store.nodes.first(where: { $0.title == "Code" })!
        let baseText = codeNode.textContent ?? ""
        let bundleID = UUID()
        let itemID = UUID()

        vm.items.append(CoCaptainTimelineItem(
            id: bundleID,
            content: .reviewBundle(ReviewBundleItem(
                id: bundleID,
                items: [PendingReviewItem(
                    id: itemID,
                    targetLabel: "Code",
                    summary: "Update headline",
                    preview: "<h1>Agentic Hello!</h1>",
                    source: .nodeEdit(
                        role: .code,
                        operations: [NodePatchOperation(type: .replaceAll, content: "<h1>Agentic Hello!</h1>")],
                        baseText: baseText
                    )
                )]
            ))
        ))

        // No user edits between suggestion and apply — should succeed.
        vm.applyReviewItem(bundleID: bundleID, itemID: itemID)

        guard case .reviewBundle(let bundle) = vm.items.first(where: { $0.id == bundleID })?.content,
              let result = bundle.items.first(where: { $0.id == itemID }) else {
            Issue.record("Review bundle or item not found")
            return
        }

        #expect(result.status == .applied)
        #expect(result.conflictDescription == nil)
    }

    @MainActor
    @Test func tokenLimitErrorAppendsProUpgradeReviewItem() async throws {
        let dispatcher = TestActionDispatcher()
        let error = TokenUsageLimitError(limitTokens: 20_000, usedTokens: 20_000, requestedTokens: 1_000)
        let coordinator = CoCaptainAgentCoordinator(llmClient: ThrowingLLMClient(error: error))
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.actionDispatcher = dispatcher

        vm.sendMessage("build a tiny app")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)

        let assistantMessage = vm.items.compactMap { item -> ChatBubbleItem? in
            guard case .message(let bubble) = item.content, !bubble.isUser else { return nil }
            return bubble
        }.last

        let proReviewBundleItem = vm.items.first { item in
            guard case .reviewBundle(let bundle) = item.content else { return false }
            return bundle.items.contains { reviewItem in
                if case .appAction(.proSubscription, nil) = reviewItem.source {
                    return true
                }
                return false
            }
        }
        let productCTAItem = vm.items.compactMap { item -> CoCaptainProductCTAItem? in
            guard case .productCTA(let cta) = item.content else { return nil }
            return cta
        }.first

        #expect(assistantMessage?.text.contains("You've reached this month's free CoCaptain usage") == true)
        #expect(proReviewBundleItem == nil)
        #expect(productCTAItem?.title == "Free CoCaptain usage reached")
        #expect(productCTAItem?.primaryButtonTitle == "View Pro")
        #expect(productCTAItem?.actionID == .proSubscription)

        guard let productCTAItem else {
            Issue.record("Expected limit-reached product CTA.")
            return
        }

        vm.performProductCTA(productCTAItem)

        #expect(dispatcher.executedActionIDs.contains(.proSubscription))
        #expect(dispatcher.executedSources.last == .user)
    }

    @MainActor
    @Test func cancelledAgentTurnClearsThinkingState() async throws {
        let coordinator = CoCaptainAgentCoordinator(llmClient: ThrowingLLMClient(error: CancellationError()))
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("hi")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
    }

    @MainActor
    private func makeStore() -> ProjectStore {
        ProjectStore(
            fileName: "onboarding-test-\(UUID().uuidString).json",
            projectName: "Test Project",
            initialNodes: [
                SpatialNode(
                    type: .srs,
                    position: CGPoint(x: 0, y: 0),
                    title: "Software Requirements (SRS)",
                    theme: .purple,
                    textContent: "Build a landing page"
                ),
                SpatialNode(
                    type: .code,
                    position: CGPoint(x: 10, y: 0),
                    title: "Code",
                    theme: .orange,
                    textContent: "<html><body><h1>Hello World!</h1></body></html>"
                )
            ]
        )
    }

    private func makePreviewNodes(code: String) -> [SpatialNode] {
        [
            SpatialNode(type: .webView, position: .zero, title: "Live Preview"),
            SpatialNode(type: .code, position: .zero, title: "Code", textContent: code)
        ]
    }
}

@MainActor
private final class ThrowingLLMClient: CoCaptainLLMClient {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}

@MainActor
private final class TestLLMClient: CoCaptainLLMClient {
    private let responses: [String]
    private let functionCalls: [[CoCaptainAgentFunctionCall]]
    private var streamCount = 0
    var receivedMessages: [String] = []
    var receivedScopes: [CoCaptainAgentScope] = []

    init(response: String) {
        self.responses = [response]
        self.functionCalls = []
    }

    init(response: String, functionCalls: [[CoCaptainAgentFunctionCall]]) {
        self.responses = [response]
        self.functionCalls = functionCalls
    }

    init(responses: [String]) {
        self.responses = responses
        self.functionCalls = []
    }

    init(responses: [String], functionCalls: [[CoCaptainAgentFunctionCall]]) {
        self.responses = responses
        self.functionCalls = functionCalls
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        receivedMessages.append(userMessage)
        receivedScopes.append(scope)
        let index = streamCount
        let response = responses[min(index, responses.count - 1)]
        let calls = functionCalls.indices.contains(index) ? functionCalls[index] : []
        streamCount += 1

        return AsyncThrowingStream { continuation in
            continuation.yield(.text(response))
            if !calls.isEmpty {
                continuation.yield(.functionCalls(calls))
            }
            continuation.finish()
        }
    }
}

@MainActor
private final class TestActionDispatcher: AppActionPerforming {
    let availableActions: [AppActionDefinition] = [
        AppActionDefinition(
            id: .goRoot,
            title: "Go to Root",
            icon: "house.fill",
            category: .navigation,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .createNode,
            title: "Create New Node",
            icon: "plus.square",
            category: .project,
            isMutating: true,
            allowsAutonomousExecution: false
        ),
        AppActionDefinition(
            id: .openSettings,
            title: "Open Settings",
            icon: "gearshape.fill",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .openProjectExplorer,
            title: "Project Explorer",
            icon: "folder.fill",
            category: .project,
            isMutating: false,
            allowsAutonomousExecution: true
        ),
        AppActionDefinition(
            id: .proSubscription,
            title: "Pro Subscription",
            icon: "crown",
            category: .assistant,
            isMutating: false,
            allowsAutonomousExecution: false
        )
    ]

    var executedActionIDs: [AppActionID] = []
    var executedSources: [AppActionSource] = []

    func definition(for id: AppActionID) -> AppActionDefinition? {
        availableActions.first(where: { $0.id == id })
    }

    @discardableResult
    func perform(_ id: AppActionID, source: AppActionSource, arguments: [String: String]? = nil) -> AppActionResult {
        guard let definition = definition(for: id) else {
            return AppActionResult(actionID: id, title: id.rawValue, executed: false, message: "Missing")
        }

        if source == .agentAutomatic && (definition.isMutating || !definition.allowsAutonomousExecution) {
            return AppActionResult(actionID: id, title: definition.title, executed: false, message: "Blocked")
        }

        executedActionIDs.append(id)
        executedSources.append(source)
        return AppActionResult(actionID: id, title: definition.title, executed: true, message: "\(definition.title) executed.")
    }
}
