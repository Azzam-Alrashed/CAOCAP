import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct CoCaptainAgentTests {
    @Test func onboardingWelcomePurposeDefinesFocusedPromptInstructions() {
        let instructions = CoCaptainTurnPurpose.onboardingWelcome.promptInstructions

        #expect(CoCaptainTurnPurpose.standard.promptInstructions == nil)
        #expect(instructions?.contains("40 to 80 words") == true)
        #expect(instructions?.contains("exactly one easy question") == true)
        #expect(instructions?.contains("at most two short example ideas") == true)
        #expect(instructions?.contains("Do not request app actions") == true)
        #expect(instructions?.contains("Match the language used by the user") == true)
    }

    @MainActor
    @Test func projectContextIncludesMiniAppsAndExcludesCompiledPreview() throws {
        let store = makeStore()
        store.nodes[0].miniApp?.compiledHTML = "<html>compiled</html>"

        let context = ProjectContextBuilder().buildPromptContext(from: store)

        #expect(context.contains("Project Name: Test Project"))
        #expect(context.contains("Mini-App Count: 1"))
        #expect(context.contains("SRS Readiness:"))
        #expect(context.contains("Build a landing page"))
        #expect(context.contains("<html><body><h1>Hello World!</h1></body></html>"))
        #expect(!context.contains("compiled"))
    }

    @MainActor
    @Test func projectContextIncludesBlankMiniAppCode() throws {
        let store = ProjectStore(
            fileName: "blank-canvas-test-\(UUID().uuidString).json",
            projectName: "Blank Project",
            initialNodes: [
                SpatialNode(
                    type: .miniApp,
                    position: CGPoint(x: 0, y: 0),
                    title: "Mini-App",
                    miniApp: MiniAppState(srsText: "Just starting out.", codeText: "")
                )
            ]
        )

        let context = ProjectContextBuilder().buildPromptContext(from: store)

        #expect(context.contains("Mini-App Count: 1"))
        #expect(context.contains("Code:"))
    }

    @MainActor
    @Test func nodeContextIncludesSelectedNodeAndLinkedNeighbors() throws {
        let linkedID = UUID()
        let selectedID = UUID()
        let unrelatedID = UUID()
        let store = ProjectStore(
            fileName: "node-context-\(UUID().uuidString).json",
            projectName: "Node Context",
            initialNodes: [
                SpatialNode(id: selectedID, type: .miniApp, position: .zero, title: "Selected Mini-App", connectedNodeIds: [linkedID], miniApp: MiniAppState(srsText: "Selected SRS content", codeText: "<h1>Selected code</h1>")),
                SpatialNode(id: linkedID, type: .miniApp, position: .zero, title: "Linked Mini-App", miniApp: MiniAppState(codeText: "<h1>Linked code</h1>")),
                SpatialNode(id: unrelatedID, type: .miniApp, position: .zero, title: "Unrelated", miniApp: MiniAppState(codeText: "Do not leak full unrelated content"))
            ]
        )

        let context = ProjectContextBuilder().buildNodePromptContext(from: store, nodeID: selectedID)

        #expect(context.contains("Selected Node ID: \(selectedID.uuidString)"))
        #expect(context.contains("Selected Node Context:"))
        #expect(context.contains("Selected SRS content"))
        #expect(context.contains("Linked Neighbor Nodes:"))
        #expect(context.contains("<h1>Linked code</h1>"))
        #expect(context.contains("Unrelated [miniApp] id: \(unrelatedID.uuidString)"))
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
                <node_edit nodeId="\(nodeID.uuidString)" role="miniApp" section="code" summary="Target exact Mini-App code.">
                  <operation type="replace_all">
                    <content><![CDATA[<h1>Targeted</h1>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.payload?.nodeEdits.first?.nodeID == nodeID)
        #expect(parsed.payload?.nodeEdits.first?.role == .miniApp)
        #expect(parsed.payload?.nodeEdits.first?.section == .code)
    }

    @MainActor
    @Test func nodePatchEngineTargetsNodeIDBeforeRoleFallback() throws {
        let targetID = UUID()
        let otherID = UUID()
        let store = ProjectStore(
            fileName: "node-patch-\(UUID().uuidString).json",
            initialNodes: [
                SpatialNode(id: otherID, type: .miniApp, position: .zero, title: "Other Mini-App", miniApp: MiniAppState(codeText: "wrong")),
                SpatialNode(id: targetID, type: .miniApp, position: .zero, title: "Custom Mini-App", miniApp: MiniAppState(codeText: "right"))
            ]
        )

        let preview = try NodePatchEngine().preview(
            nodeID: targetID,
            role: .miniApp,
            section: .code,
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
        let node = store.nodes.first(where: { $0.role == .miniApp })!

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
        #expect(SpatialNode(type: .miniApp, position: .zero, title: "Mini-App").role == .miniApp)
        #expect(SpatialNode(type: .subCanvas, position: .zero, title: "Nested").role == .subCanvas)
        #expect(SpatialNode(position: .zero, title: "New Logic").role == .custom)
    }

    @Test func livePreviewCompilerInjectsFirebaseWhenMiniAppConfigPresent() throws {
        let miniApp = SpatialNode(
            type: .miniApp,
            position: .zero,
            title: "Mini-App",
            theme: .blue,
            miniApp: MiniAppState(
                codeText: "<html><head></head><body><p>x</p></body></html>",
                firebaseConfigText: #"{"apiKey":"testKey","authDomain":"t.firebaseapp.com","projectId":"tid","storageBucket":"t.appspot.com","messagingSenderId":"1","appId":"1:1:web:abc"}"#
            )
        )
        let compilation = try #require(LivePreviewCompiler().compile(nodes: [miniApp]))
        #expect(compilation.html.contains("__caocap_fb_b64"))
        #expect(compilation.html.contains("firebase-app-compat.js"))
    }

    @Test func livePreviewCompilerUsesFirstMiniAppWhenMultipleExist() throws {
        let nodes = [
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<html><body><h1>Combined</h1></body></html>")),
            SpatialNode(type: .miniApp, position: .zero, title: "Other Mini-App", miniApp: MiniAppState(codeText: "<h1>Ignored</h1>"))
        ]

        let compilation = try #require(LivePreviewCompiler().compile(nodes: nodes))

        #expect(compilation.html.contains("Combined"))
        #expect(!compilation.html.contains("Ignored"))
    }

    @Test func livePreviewCompilerInjectsFirebaseIntoMiniAppCode() throws {
        let nodes = [
            SpatialNode(
                type: .miniApp,
                position: .zero,
                title: "Mini-App",
                miniApp: MiniAppState(
                    codeText: "<html><head></head><body><h1>Combined</h1></body></html>",
                    firebaseConfigText: #"{"apiKey":"testKey","authDomain":"t.firebaseapp.com","projectId":"tid","storageBucket":"t.appspot.com","messagingSenderId":"1","appId":"1:1:web:abc"}"#
                )
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
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<html><head><meta name=\"viewport\" content=\"width=device-width\"></head><body></body></html>"))
        ]
        let compilationDouble = try #require(compiler.compile(nodes: hasViewportDouble))
        #expect(compilationDouble.html.components(separatedBy: "viewport").count == 2)
        
        // Scenario 2: Already has viewport tag (single quotes)
        let hasViewportSingle = [
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<html><head><meta name='viewport' content='width=device-width'></head><body></body></html>"))
        ]
        let compilationSingle = try #require(compiler.compile(nodes: hasViewportSingle))
        #expect(compilationSingle.html.components(separatedBy: "viewport").count == 2)
        
        // Scenario 3: Has <head>, missing viewport
        let missingViewportWithHead = [
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<html><head><title>Test</title></head><body><h1>Hello</h1></body></html>"))
        ]
        let compilationWithHead = try #require(compiler.compile(nodes: missingViewportWithHead))
        #expect(compilationWithHead.html.contains("viewport"))
        #expect(compilationWithHead.html.contains("<head>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"))
        
        // Scenario 4: Has <html>, missing <head>
        let missingViewportWithHtml = [
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<html><body><h1>Hello</h1></body></html>"))
        ]
        let compilationWithHtml = try #require(compiler.compile(nodes: missingViewportWithHtml))
        #expect(compilationWithHtml.html.contains("viewport"))
        #expect(compilationWithHtml.html.contains("<head>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n</head>"))
        
        // Scenario 5: Missing both <head> and <html>
        let missingViewportFragment = [
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<h1>Hello World</h1>"))
        ]
        let compilationFragment = try #require(compiler.compile(nodes: missingViewportFragment))
        #expect(compilationFragment.html.contains("viewport"))
        #expect(compilationFragment.html.contains("<!DOCTYPE html>"))
        #expect(compilationFragment.html.contains("<html><head>"))
    }

    @Test func livePreviewCompilerRequiresMiniAppNode() {
        let compiler = LivePreviewCompiler()
        let standardOnly = [SpatialNode(type: .standard, position: .zero, title: "Note")]

        #expect(compiler.compile(nodes: standardOnly) == nil)
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
    @Test func commandIntentResolverDoesNotMatchRemovedProjectCommands() throws {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("create a project", availableActions: actions) == nil)
        #expect(resolver.resolve("please create a project", availableActions: actions) == nil)
        #expect(resolver.resolve("new project", availableActions: actions) == nil)
        #expect(resolver.resolve("open settings", availableActions: actions) == .openSettings)
        #expect(resolver.resolve("make a root page", availableActions: actions) == nil)
        #expect(resolver.resolve("do not create a project", availableActions: actions) == nil)
    }

    @MainActor
    @Test func commandIntentResolverMatchesArabicSettingsCommands() throws {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("أنشئ مشروع جديد", availableActions: actions) == nil)
        #expect(resolver.resolve("لو سمحت أنشئ مشروع جديد", availableActions: actions) == nil)
        #expect(resolver.resolve("افتح الإعدادات", availableActions: actions) == .openSettings)
        #expect(resolver.resolve("اعرض المشاريع", availableActions: actions) == nil)
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
    @Test func commandPaletteKeepsPromptSelectedDuringOnboardingTyping() {
        let viewModel = CommandPaletteViewModel()
        viewModel.actions = TestActionDispatcher().availableActions
        viewModel.nodes = [
            SpatialNode(type: .standard, position: .zero, title: "Hi from the canvas")
        ]

        viewModel.query = "h"
        viewModel.selectPromptRowIfAvailable()
        viewModel.prefersPromptSubmission = true
        viewModel.query = "hi"

        var submittedPrompt: String?
        var flownNodeID: UUID?
        viewModel.onSubmitPrompt = { submittedPrompt = $0 }
        viewModel.onFlyToNode = { flownNodeID = $0 }

        #expect(viewModel.nodeResults.count == 1)
        #expect(viewModel.selectedIndex == viewModel.promptSelectionIndex)

        viewModel.confirmSelection()

        #expect(submittedPrompt == "hi")
        #expect(flownNodeID == nil)
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
                <node_edit role="miniApp" section="srs" summary="Document color preference.">
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
                <node_edit role="miniApp" section="code" summary="Update Code.">
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
        #expect(directive.payload?.nodeEdits.first?.role == .miniApp)
        #expect(directive.payload?.nodeEdits.first?.section == .code)
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
                    <node_edit role="miniApp" section="code" summary="Update Code.">
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
    @Test func coordinatorForwardsOnboardingWelcomePurpose() async throws {
        let llm = TestLLMClient(
            response: "Welcome! What would you like to make?"
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "hi",
            store: makeStore(),
            dispatcher: nil,
            purpose: .onboardingWelcome
        ) { _ in }

        #expect(llm.receivedPurposes == [.onboardingWelcome])
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
                    <node_edit role="miniApp" section="srs" summary="Draft the product requirements.">
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
        #expect(result.reviewBundle?.items.first?.targetLabel == "Mini-App SRS")
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
                    <node_edit role="miniApp" section="code" summary="Update the headline.">
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
        let miniAppNode = try #require(store.nodes.first(where: { $0.role == .miniApp }))
        let llm = TestLLMClient(
            response:
                """
                I prepared a code-node update.

                <cocaptain_actions>
                  <assistant_message>I prepared a code-node update.</assistant_message>
                  <node_edits>
                    <node_edit nodeId="\(miniAppNode.id.uuidString)" role="miniApp" section="code" summary="Update targeted mini-app.">
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
            scope: .node(miniAppNode.id)
        ) { _ in }

        #expect(llm.receivedScopes == [.node(miniAppNode.id)])
        #expect(result.reviewBundle?.items.first?.targetNodeID == miniAppNode.id)
        #expect(result.reviewBundle?.items.first?.targetLabel == "Mini-App CODE")
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
                    <node_edit role="miniApp" section="code" summary="Update Code.">
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """,
                """
                I prepared a valid code edit.

                <cocaptain_actions>
                  <assistant_message>I prepared a valid code edit.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update Code.">
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

        let miniAppNode = store.nodes.first(where: { $0.title == "Mini-App" })!
        let baseText = miniAppNode.miniApp?.codeText ?? ""
        let bundleID = UUID()
        let itemID = UUID()

        vm.items.append(CoCaptainTimelineItem(
            id: bundleID,
            content: .reviewBundle(ReviewBundleItem(
                id: bundleID,
                items: [PendingReviewItem(
                    id: itemID,
                    targetLabel: "Mini-App CODE",
                    summary: "Update headline",
                    preview: "<h1>Agentic Hello!</h1>",
                    source: .nodeEdit(
                        role: .miniApp,
                        section: .code,
                        operations: [NodePatchOperation(type: .replaceAll, content: "<h1>Agentic Hello!</h1>")],
                        baseText: baseText
                    )
                )]
            ))
        ))

        // User edits the Mini-App code before clicking Apply — stale scenario.
        store.updateMiniAppCode(id: miniAppNode.id, text: "<h1>User wrote this instead</h1>", persist: false)
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

        let miniAppNode = store.nodes.first(where: { $0.title == "Mini-App" })!
        let baseText = miniAppNode.miniApp?.codeText ?? ""
        let bundleID = UUID()
        let itemID = UUID()

        vm.items.append(CoCaptainTimelineItem(
            id: bundleID,
            content: .reviewBundle(ReviewBundleItem(
                id: bundleID,
                items: [PendingReviewItem(
                    id: itemID,
                    targetLabel: "Mini-App CODE",
                    summary: "Update headline",
                    preview: "<h1>Agentic Hello!</h1>",
                    source: .nodeEdit(
                        role: .miniApp,
                        section: .code,
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
        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 0)

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
    @Test func completedAssistantResponseCountAdvancesAfterSuccessfulAgentTurn() async throws {
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
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.store = makeStore()
        vm.actionDispatcher = dispatcher

        vm.sendMessage("help me from the model")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(dispatcher.executedActionIDs == [.openSettings])
    }

    @MainActor
    @Test func completedAssistantResponseCountAdvancesForDirectCommandResponses() {
        let dispatcher = TestActionDispatcher()
        let vm = CoCaptainViewModel()
        vm.actionDispatcher = dispatcher

        vm.sendMessage("open settings")

        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(dispatcher.executedActionIDs == [.openSettings])
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
        #expect(vm.completedAssistantResponseCount == 0)
        #expect(vm.successfulAssistantResponseCount == 0)
    }

    @MainActor
    @Test func failedOnboardingWelcomeCanRetryWithoutCountingFailureAsSuccess() async throws {
        let llm = FailingThenSucceedingLLMClient(failureCount: 2)
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("hi", purpose: .onboardingWelcome)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 0)
        #expect(vm.items.contains { item in
            guard case .message(let bubble) = item.content else { return false }
            return bubble.text.contains("Please try sending your message again.")
        })

        vm.sendMessage("hi again", purpose: .onboardingWelcome)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.completedAssistantResponseCount == 2)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(llm.receivedPurposes.allSatisfy { $0 == .onboardingWelcome })
    }

    @MainActor
    private func makeStore() -> ProjectStore {
        ProjectStore(
            fileName: "onboarding-test-\(UUID().uuidString).json",
            projectName: "Test Project",
            initialNodes: [
                SpatialNode(
                    type: .miniApp,
                    position: CGPoint(x: 0, y: 0),
                    title: "Mini-App",
                    theme: .blue,
                    miniApp: MiniAppState(
                        srsText: "Build a landing page",
                        codeText: "<html><body><h1>Hello World!</h1></body></html>"
                    )
                )
            ]
        )
    }

    private func makePreviewNodes(code: String) -> [SpatialNode] {
        [
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: code))
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
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose
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
    var receivedPurposes: [CoCaptainTurnPurpose] = []

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
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        receivedMessages.append(userMessage)
        receivedScopes.append(scope)
        receivedPurposes.append(purpose)
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
private final class FailingThenSucceedingLLMClient: CoCaptainLLMClient {
    private var remainingFailures: Int
    var receivedPurposes: [CoCaptainTurnPurpose] = []

    init(failureCount: Int) {
        self.remainingFailures = failureCount
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        receivedPurposes.append(purpose)

        if remainingFailures > 0 {
            remainingFailures -= 1
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: NSError(
                        domain: "CoCaptainOnboardingTest",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Temporary model failure"]
                    )
                )
            }
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.text("Welcome! What would you like to make?"))
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
