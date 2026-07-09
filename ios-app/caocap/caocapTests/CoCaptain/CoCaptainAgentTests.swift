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

    @Test func onboardingBuildHandoffPurposeDefinesFocusedPromptInstructions() {
        let instructions = CoCaptainTurnPurpose.onboardingBuildHandoff.promptInstructions

        #expect(instructions?.contains("initial direction for what they want to build") == true)
        #expect(instructions?.contains("20 to 50 words") == true)
        #expect(instructions?.contains("transition back to the canvas") == true)
        #expect(instructions?.contains("Do not ask a question") == true)
        #expect(instructions?.contains("Do not request app actions") == true)
        #expect(instructions?.contains("invoke tools") == true)
        #expect(instructions?.contains("emit a `cocaptain_actions` block") == true)
        #expect(instructions?.contains("Match the language used by the user") == true)
    }

    @Test func turnCompletionShouldAdvanceToCanvasDismissalOnlyForSuccessfulHandoff() {
        let handoffSuccess = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingBuildHandoff,
            succeeded: true
        )
        let handoffFailure = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingBuildHandoff,
            succeeded: false
        )
        let welcomeSuccess = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingWelcome,
            succeeded: true
        )
        let standardSuccess = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .standard,
            succeeded: true
        )

        #expect(handoffSuccess.shouldAdvanceToCanvasDismissal)
        #expect(!handoffFailure.shouldAdvanceToCanvasDismissal)
        #expect(!welcomeSuccess.shouldAdvanceToCanvasDismissal)
        #expect(!standardSuccess.shouldAdvanceToCanvasDismissal)
    }

    @Test func turnExecutionPolicyMapsPurposesToExpectedModes() {
        #expect(CoCaptainTurnPurpose.standard.executionPolicy == .agent)
        #expect(CoCaptainTurnPurpose.onboardingWelcome.executionPolicy == .conversational)
        #expect(CoCaptainTurnPurpose.onboardingBuildHandoff.executionPolicy == .conversational)
        #expect(CoCaptainTurnPurpose.onboardingGuidedEdit.executionPolicy == .agentic)
        #expect(!CoCaptainTurnPurpose.standard.isConversationalTurn)
        #expect(CoCaptainTurnPurpose.onboardingWelcome.isConversationalTurn)
        #expect(CoCaptainTurnPurpose.onboardingBuildHandoff.isConversationalTurn)
        #expect(!CoCaptainTurnPurpose.onboardingGuidedEdit.isConversationalTurn)
    }

    @Test func turnPlanMapsModeAndPurposeToEffectivePolicy() {
        let agent = CoCaptainTurnPlan(purpose: .standard, mode: .agent)
        let ask = CoCaptainTurnPlan(purpose: .standard, mode: .ask)
        let welcome = CoCaptainTurnPlan(purpose: .onboardingWelcome, mode: .agent)
        let handoff = CoCaptainTurnPlan(purpose: .onboardingBuildHandoff, mode: .agent)
        let guided = CoCaptainTurnPlan(purpose: .onboardingGuidedEdit, mode: .ask)

        #expect(agent.effectivePolicy == .agent)
        #expect(ask.effectivePolicy == .ask)
        #expect(welcome.effectivePolicy == .conversational)
        #expect(handoff.effectivePolicy == .conversational)
        #expect(guided.effectivePolicy == .agentic)
        #expect(CoCaptainTurnExecutionPolicy.agent.expectsStructuredResponse)
        #expect(CoCaptainTurnExecutionPolicy.agent.enforcesExecutableWork == false)
        #expect(CoCaptainTurnExecutionPolicy.agent.allowsAgenticRetry)
        #expect(CoCaptainTurnExecutionPolicy.agent.executesActions)
        #expect(CoCaptainTurnExecutionPolicy.ask.expectsStructuredResponse == false)
        #expect(CoCaptainTurnExecutionPolicy.ask.executesActions == false)
        #expect(CoCaptainTurnExecutionPolicy.ask.enforcesExecutableWork == false)
        #expect(CoCaptainTurnExecutionPolicy.ask.allowsAgenticRetry == false)
        #expect(CoCaptainTurnExecutionPolicy.agentic.enforcesExecutableWork)
        #expect(agent.requiresDegradedConnectionNotice)
        #expect(!ask.requiresDegradedConnectionNotice)
        #expect(!welcome.requiresDegradedConnectionNotice)
        #expect(guided.requiresDegradedConnectionNotice)
        #expect(agent.contextDetailLevel == .implementation)
        #expect(ask.contextDetailLevel == .product)
    }

    @MainActor
    @Test func productContextOmitsFirebaseImplementationDetails() throws {
        let store = makeStore()
        store.nodes[0].miniApp?.firebaseConfigText = #"{"apiKey":"test"}"#

        let context = ProjectContextBuilder().buildPromptContext(from: store, detailLevel: .product)

        #expect(context.contains("SRS Readiness:"))
        #expect(!context.contains("Mini-App Firebase wiring rules"))
        #expect(!context.contains("__caocapFirestore"))
        #expect(!context.contains("Firebase Config:"))
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

    @Test func functionCallAdapterAcceptsUppercaseExecutionMode() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["actionId": "go_root", "executionMode": "SAFE"]
            )
        ])

        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.diagnostics.isEmpty)
    }

    @MainActor
    @Test func coordinatorRetriesDuplicateSafeActions() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                """
                Navigating.

                <cocaptain_actions>
                  <assistant_message>Navigating.</assistant_message>
                  <safe_actions>
                    <action id="go_root"/>
                    <action id="go_root"/>
                  </safe_actions>
                </cocaptain_actions>
                """,
                """
                Navigating.

                <cocaptain_actions>
                  <assistant_message>Navigating.</assistant_message>
                  <safe_actions><action id="go_root"/></safe_actions>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "go root",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("is duplicated") == true)
        #expect(dispatcher.executedActionIDs == [.goRoot])
        #expect(result.executionSummary?.summary.contains("Go to Root") == true)
    }

    @Test func parserUsesLastCompleteActionsBlock() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            First attempt.

            <cocaptain_actions>
              <assistant_message>Old payload.</assistant_message>
              <safe_actions><action id="go_root"/></safe_actions>
            </cocaptain_actions>

            Second attempt.

            <cocaptain_actions>
              <assistant_message>Latest payload.</assistant_message>
              <safe_actions><action id="open_settings"/></safe_actions>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.preamble == "First attempt.\n\nSecond attempt.")
        #expect(parsed.payload?.assistantMessage == "Latest payload.")
        #expect(parsed.payload?.safeActions.first?.actionID == "open_settings")
    }

    @Test func parserIgnoresTrailingIncompleteActionsBlock() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            Working on it.

            <cocaptain_actions>
              <assistant_message>Valid payload.</assistant_message>
              <safe_actions><action id="go_root"/></safe_actions>
            </cocaptain_actions>

            <cocaptain_actions>
              <assistant_message>Still generating...
            """

        let parsed = parser.parse(response)

        #expect(parsed.payload?.assistantMessage == "Valid payload.")
        #expect(parsed.payload?.safeActions.first?.actionID == "go_root")
    }

    @MainActor
    @Test func validatorRejectsDuplicateAndOverlappingActions() {
        let payload = CoCaptainAgentPayload(
            assistantMessage: "Ready",
            safeActions: [
                CoCaptainAgentAction(actionID: "go_root"),
                CoCaptainAgentAction(actionID: "go_root")
            ],
            pendingActions: [
                CoCaptainAgentAction(actionID: "create_node"),
                CoCaptainAgentAction(actionID: "create_node"),
                CoCaptainAgentAction(actionID: "go_root")
            ]
        )

        let result = CoCaptainAgentValidator().validate(
            payload: payload,
            dispatcher: TestActionDispatcher(),
            requiresAgenticWork: false
        )

        #expect(!result.isValid)
        #expect(result.issues.contains { $0.contains("Safe action `go_root` is duplicated.") })
        #expect(result.issues.contains { $0.contains("Pending action `create_node` is duplicated.") })
        #expect(result.issues.contains { $0.contains("cannot appear in both") })
    }

    @Test func functionCallAdapterAcceptsSnakeCaseActionID() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["action_id": "go_root", "executionMode": "safe"]
            )
        ])

        #expect(directive.payload?.safeActions.first?.actionID == "go_root")
        #expect(directive.diagnostics.isEmpty)
    }

    @MainActor
    @Test func commandIntentResolverMatchesGoHomeAndHelpCenter() throws {
        let resolver = CommandIntentResolver()
        let actions = TestActionDispatcher().availableActions

        #expect(resolver.resolve("go home", availableActions: actions) == .goRoot)
        #expect(resolver.resolve("open help center", availableActions: actions) == .help)
    }

    @MainActor
    @Test func coordinatorReviewBundleTitleIncludesItemCount() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response:
                """
                Prepared two changes.

                <cocaptain_actions>
                  <assistant_message>Prepared two changes.</assistant_message>
                  <pending_actions><action id="create_node"/></pending_actions>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update headline.">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Updated</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update and create",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(result.reviewBundle?.items.count == 2)
        #expect(result.reviewBundle?.title.contains("2") == true)
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

    @Test func functionCallAdapterPreservesSupplementalArguments() throws {
        let adapter = CoCaptainFunctionCallAgentAdapter()
        let directive = adapter.directive(
            from: [
                CoCaptainAgentFunctionCall(
                    name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                    arguments: [
                        "actionId": "moveNode",
                        "executionMode": "pending",
                        "nodeId": "ABC-123",
                        "x": "120",
                        "y": "80"
                    ]
                )
            ]
        )

        let action = try #require(directive.payload?.pendingActions.first)
        #expect(action.actionID == "moveNode")
        #expect(action.args?["nodeId"] == "ABC-123")
        #expect(action.args?["x"] == "120")
        #expect(action.args?["y"] == "80")
        #expect(action.args?["executionMode"] == nil)
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
    @Test func coordinatorForwardsOnboardingBuildHandoffPurpose() async throws {
        let llm = TestLLMClient(
            response: "Great idea. Let's head back to the canvas and start building."
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "a todo app",
            store: makeStore(),
            dispatcher: nil,
            purpose: .onboardingBuildHandoff
        ) { _ in }

        #expect(llm.receivedPurposes == [.onboardingBuildHandoff])
    }

    @MainActor
    @Test func conversationalBuildHandoffDoesNotAgenticRetryForMakeKeyword() async throws {
        let llm = TestLLMClient(
            response: "A Pac-Man game sounds fun. Let's head back to the canvas and start building."
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "I wanna make a pacman game",
            store: makeStore(),
            dispatcher: nil,
            purpose: .onboardingBuildHandoff
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(llm.receivedMessages.allSatisfy {
            !$0.contains("machine-readable CoCaptain action contract")
        })
        #expect(!result.visibleText.isEmpty)
        #expect(result.reviewBundle == nil)
        #expect(result.executionSummary == nil)
    }

    @MainActor
    @Test func conversationalTurnIgnoresStructuredPayloadFromModel() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response: """
            A Pac-Man game sounds fun. Let's head back to the canvas.

            <cocaptain_actions>
              <assistant_message>I built Pac-Man.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Build Pac-Man.">
                  <operation type="replace_all">
                    <content><![CDATA[<html><body>Pac-Man</body></html>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "I wanna make a pacman game",
            store: makeStore(),
            dispatcher: dispatcher,
            purpose: .onboardingBuildHandoff
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewBundle == nil)
        #expect(result.executionSummary == nil)
        #expect(result.visibleText.contains("Pac-Man"))
        #expect(dispatcher.executedActionIDs.isEmpty)
    }

    @MainActor
    @Test func standardTurnAgenticRetriesWhenBuildRequestHasNoStructuredPayload() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            responses: [
                "A Pac-Man game sounds fun. We can build that together.",
                """
                I prepared a Pac-Man starter.

                <cocaptain_actions>
                  <assistant_message>I prepared a Pac-Man starter.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Build Pac-Man.">
                      <operation type="replace_all">
                        <content><![CDATA[<html><body>Pac-Man</body></html>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "I wanna make a pacman game",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages.last?.contains("machine-readable CoCaptain action contract") == true)
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
    @Test func coordinatorReturnsFriendlyMessageWhenRetryPayloadIsStillInvalid() async throws {
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
        #expect(result.reviewBundle == nil)
        #expect(result.payloadMessage?.contains("another run") == true)
        #expect(llm.receivedMessages.count == 3)
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

    @Test func parserExtractsLearningNoteFromNodeEdit() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            Done.

            <cocaptain_actions>
              <assistant_message>Updated the headline.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Update headline">
                  <operation type="replace_all">
                    <content><![CDATA[<h1>New</h1>]]></content>
                  </operation>
                  <learning_note concept="Headings">The h1 tag is your page's headline. Changing its text changes what visitors see first.</learning_note>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)
        let note = parsed.payload?.nodeEdits.first?.learningNote

        #expect(note?.concept == "Headings")
        #expect(note?.body.contains("headline") == true)
    }

    @Test func parserDegradesMalformedLearningNoteWithoutInvalidatingEdit() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            <cocaptain_actions>
              <assistant_message>Updated.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Update headline">
                  <operation type="replace_all">
                    <content><![CDATA[<h1>New</h1>]]></content>
                  </operation>
                  <learning_note>Missing concept attribute.</learning_note>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """

        let parsed = parser.parse(response)

        #expect(parsed.payload?.nodeEdits.count == 1)
        #expect(parsed.payload?.nodeEdits.first?.learningNote == nil)
    }

    @MainActor
    @Test func coordinatorCarriesLearningNoteIntoReviewItem() async throws {
        let llm = TestLLMClient(
            response:
                """
                Updating now.

                <cocaptain_actions>
                  <assistant_message>Updated the headline.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update headline">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>New</h1>]]></content>
                      </operation>
                      <learning_note concept="Headings">The h1 tag is your page's main headline.</learning_note>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update the headline",
            store: makeStore(),
            dispatcher: TestActionDispatcher()
        ) { _ in }

        let note = result.reviewBundle?.items.first?.learningNote
        #expect(note?.concept == "Headings")
        #expect(note?.body == "The h1 tag is your page's main headline.")
    }

    @MainActor
    @Test func coordinatorBuildsFallbackLearningNoteWhenModelOmitsOne() async throws {
        let llm = TestLLMClient(
            response:
                """
                <cocaptain_actions>
                  <assistant_message>Updated the headline.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update headline">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>New</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update the headline",
            store: makeStore(),
            dispatcher: TestActionDispatcher()
        ) { _ in }

        let note = result.reviewBundle?.items.first?.learningNote
        #expect(note != nil)
        #expect(note?.body.contains("Update headline") == true)
        #expect(note?.body.contains("Headline shows New") == false)
    }

    @MainActor
    @Test func applyReviewItemAppendsMentorNoteCardOnApply() {
        let store = makeStore()
        let vm = CoCaptainViewModel()
        vm.store = store

        let miniAppNode = store.nodes.first(where: { $0.title == "Mini-App" })!
        let baseText = miniAppNode.miniApp?.codeText ?? ""
        let bundleID = UUID()
        let itemID = UUID()
        let note = CoCaptainLearningNote(concept: "Headings", body: "The h1 tag is your headline.")

        vm.items.append(CoCaptainTimelineItem(
            id: bundleID,
            content: .reviewBundle(ReviewBundleItem(
                id: bundleID,
                items: [PendingReviewItem(
                    id: itemID,
                    targetLabel: "Mini-App CODE",
                    summary: "Update headline",
                    preview: "<h1>New</h1>",
                    source: .nodeEdit(
                        role: .miniApp,
                        section: .code,
                        operations: [NodePatchOperation(type: .replaceAll, content: "<h1>New</h1>")],
                        baseText: baseText
                    ),
                    learningNote: note
                )]
            ))
        ))

        vm.applyReviewItem(bundleID: bundleID, itemID: itemID)

        let mentorNotes = vm.items.compactMap { item -> CoCaptainMentorNoteItem? in
            guard case .mentorNote(let noteItem) = item.content else { return nil }
            return noteItem
        }
        #expect(mentorNotes.count == 1)
        #expect(mentorNotes.first?.note == note)

        // The note must appear after the execution confirmation.
        let executionIndex = vm.items.firstIndex { if case .execution = $0.content { return true } else { return false } }
        let noteIndex = vm.items.firstIndex { if case .mentorNote = $0.content { return true } else { return false } }
        #expect(executionIndex != nil && noteIndex != nil && executionIndex! < noteIndex!)
    }

    @MainActor
    @Test func applyReviewItemDoesNotAppendMentorNoteOnConflict() {
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
                    preview: "<h1>New</h1>",
                    source: .nodeEdit(
                        role: .miniApp,
                        section: .code,
                        operations: [NodePatchOperation(type: .replaceAll, content: "<h1>New</h1>")],
                        baseText: baseText
                    ),
                    learningNote: CoCaptainLearningNote(concept: "Headings", body: "Body.")
                )]
            ))
        ))

        store.updateMiniAppCode(id: miniAppNode.id, text: "<h1>User change</h1>", persist: false)
        vm.applyReviewItem(bundleID: bundleID, itemID: itemID)

        let hasMentorNote = vm.items.contains { if case .mentorNote = $0.content { return true } else { return false } }
        #expect(!hasMentorNote)
    }

    @Test func pendingReviewItemDecodesLegacyPayloadWithoutLearningNote() throws {
        let legacy = PendingReviewItem(
            targetLabel: "Mini-App CODE",
            summary: "Update headline",
            preview: "<h1>New</h1>",
            source: .nodeEdit(role: .miniApp, section: .code, operations: [], baseText: "")
        )
        var object = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any]
        )
        object.removeValue(forKey: "learningNote")
        let strippedData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(PendingReviewItem.self, from: strippedData)

        #expect(decoded.learningNote == nil)
        #expect(decoded.summary == "Update headline")
    }

    @Test func agentJSONValuePreservesNestedObjectsAndArrays() throws {
        let json = """
        {"summary": "Update", "operations": [{"type": "replace_all", "content": "<h1>New</h1>"}], "count": 2, "flag": true}
        """
        let decoded = try JSONDecoder().decode(
            [String: AgentJSONValue].self,
            from: Data(json.utf8)
        )

        #expect(decoded["summary"]?.stringValue == "Update")
        #expect(decoded["count"]?.stringValue == "2")
        #expect(decoded["flag"]?.stringValue == "true")
        let operations = decoded["operations"]?.arrayValue
        #expect(operations?.count == 1)
        #expect(operations?.first?.objectValue?["type"]?.stringValue == "replace_all")
        #expect(decoded["operations"]?.stringValue == nil)
    }

    @MainActor
    @Test func coordinatorAnswersReadNodeSectionToolInline() async throws {
        let store = makeStore()
        let nodeID = store.nodes.first(where: { $0.title == "Mini-App" })!.id
        let llm = ToolLoopLLMClient(
            toolCall: CoCaptainAgentFunctionCall(
                name: CoCaptainReadNodeSectionTool.name,
                arguments: ["nodeId": .string(nodeID.uuidString), "section": "code"]
            ),
            finalResponse:
                """
                <cocaptain_actions>
                  <assistant_message>Read the code and prepared an edit.</assistant_message>
                  <node_edits>
                    <node_edit nodeId="\(nodeID.uuidString)" role="miniApp" section="code" summary="Update headline">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>New</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update the headline",
            store: store,
            dispatcher: TestActionDispatcher()
        ) { _ in }

        // The read tool was answered inline with the node's real code.
        #expect(llm.capturedToolResults.count == 1)
        #expect(llm.capturedToolResults.first?.contains("<h1>Hello World!</h1>") == true)
        // The turn still produced a normal review bundle from the follow-up response.
        #expect(result.reviewBundle?.items.first?.status == .pending)
    }

    @MainActor
    @Test func readNodeSectionToolReturnsErrorTextForUnknownNode() async throws {
        let store = makeStore()
        let llm = ToolLoopLLMClient(
            toolCall: CoCaptainAgentFunctionCall(
                name: CoCaptainReadNodeSectionTool.name,
                arguments: ["nodeId": .string(UUID().uuidString), "section": "code"]
            ),
            finalResponse: "That node does not exist."
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try? await coordinator.run(
            userMessage: "what's in that node?",
            store: store,
            dispatcher: TestActionDispatcher()
        ) { _ in }

        #expect(llm.capturedToolResults.first?.hasPrefix("Error:") == true)
    }

    @MainActor
    @Test func toolExecutorLeavesRequestAppActionToAdapterRouting() async throws {
        let store = makeStore()
        let llm = ToolLoopLLMClient(
            toolCall: CoCaptainAgentFunctionCall(
                name: CoCaptainFunctionCallAgentAdapter.requestAppActionName,
                arguments: ["actionId": "go_root", "executionMode": "safe"]
            ),
            finalResponse: "Navigating."
        )
        let dispatcher = TestActionDispatcher()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "go home please",
            store: store,
            dispatcher: dispatcher
        ) { _ in }

        // Executor must decline (nil) so the call routes through the adapters.
        #expect(llm.capturedToolResults.isEmpty)
        #expect(dispatcher.executedActionIDs == [.goRoot])
        #expect(result.executionSummary != nil)
    }

    @MainActor
    @Test func slimContextSummarizesNonSelectedMiniAppCode() throws {
        let longCode = "<html><body>" + String(repeating: "<p>line</p>\n", count: 200) + "</body></html>"
        let store = ProjectStore(
            fileName: "slim-context-\(UUID().uuidString).json",
            projectName: "Slim",
            initialNodes: [
                SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(srsText: "SRS", codeText: longCode))
            ]
        )

        let context = ProjectContextBuilder(usesOnDemandCodeReads: true)
            .buildPromptContext(from: store)

        #expect(context.contains("call read_node_section for the full text"))
        #expect(context.contains("characters total"))
        #expect(!context.contains("</body></html>"))
    }

    @MainActor
    @Test func fullBudgetContextKeptWhenOnDemandReadsUnavailable() throws {
        let code = "<html><body>" + String(repeating: "<p>line</p>\n", count: 80) + "</body></html>"
        let store = ProjectStore(
            fileName: "full-context-\(UUID().uuidString).json",
            projectName: "Full",
            initialNodes: [
                SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(srsText: "SRS", codeText: code))
            ]
        )

        let context = ProjectContextBuilder(usesOnDemandCodeReads: false)
            .buildPromptContext(from: store)

        #expect(!context.contains("call read_node_section for the full text"))
        #expect(context.contains("</body></html>"))
    }

    @MainActor
    @Test func nodeScopedSelectedNodeKeepsFullCodeBudget() throws {
        let selectedID = UUID()
        let linkedID = UUID()
        let selectedCode = "<html><body>" + String(repeating: "<div>selected</div>\n", count: 100) + "<footer>selected-end</footer></body></html>"
        let linkedCode = "<html><body>" + String(repeating: "<div>linked</div>\n", count: 100) + "<footer>linked-end</footer></body></html>"
        let store = ProjectStore(
            fileName: "selected-budget-\(UUID().uuidString).json",
            projectName: "Budgets",
            initialNodes: [
                SpatialNode(id: selectedID, type: .miniApp, position: .zero, title: "Selected", connectedNodeIds: [linkedID], miniApp: MiniAppState(codeText: selectedCode)),
                SpatialNode(id: linkedID, type: .miniApp, position: .zero, title: "Linked", miniApp: MiniAppState(codeText: linkedCode))
            ]
        )

        let context = ProjectContextBuilder(usesOnDemandCodeReads: true)
            .buildNodePromptContext(from: store, nodeID: selectedID)

        // Selected node keeps its full budget; the linked neighbor is slimmed.
        #expect(context.contains("selected-end"))
        #expect(!context.contains("linked-end"))
        #expect(context.contains("call read_node_section for the full text"))
    }

    @MainActor
    @Test func flyToReviewTargetInvokesCallback() {
        let vm = CoCaptainViewModel()
        let nodeID = UUID()
        var flownNodeID: UUID?
        vm.onFlyToNode = { flownNodeID = $0 }

        vm.flyToReviewTarget(nodeID)

        #expect(flownNodeID == nodeID)
    }

    @MainActor
    @Test func applyAllCreatesSingleCheckpointForBatchApply() {
        let store = makeStore()
        let vm = CoCaptainViewModel()
        vm.store = store

        let miniAppNode = store.nodes.first(where: { $0.title == "Mini-App" })!
        let baseText = miniAppNode.miniApp?.codeText ?? ""
        let bundleID = UUID()

        vm.items.append(CoCaptainTimelineItem(
            id: bundleID,
            content: .reviewBundle(ReviewBundleItem(
                items: [
                    PendingReviewItem(
                        targetLabel: "Mini-App CODE 1",
                        summary: "First change",
                        preview: "<h1>First</h1>",
                        source: .nodeEdit(
                            role: .miniApp,
                            section: .code,
                            operations: [NodePatchOperation(type: .replaceAll, content: "<h1>First</h1>")],
                            baseText: baseText
                        )
                    ),
                    PendingReviewItem(
                        targetLabel: "Mini-App SRS",
                        summary: "SRS update",
                        preview: "Updated SRS",
                        source: .nodeEdit(
                            role: .miniApp,
                            section: .srs,
                            operations: [NodePatchOperation(type: .replaceAll, content: "Updated SRS")],
                            baseText: miniAppNode.miniApp?.srsText ?? ""
                        )
                    )
                ]
            ))
        ))

        let checkpointsBefore = store.history.count
        vm.applyAll(in: bundleID)

        #expect(store.history.count == checkpointsBefore + 1)
        #expect(store.history.first?.label == "Apply All Changes")
    }

    @MainActor
    @Test func applyAllLeavesConflictedItemsWhenOneItemIsStale() {
        let store = makeStore()
        let vm = CoCaptainViewModel()
        vm.store = store

        let miniAppNode = store.nodes.first(where: { $0.title == "Mini-App" })!
        let baseText = miniAppNode.miniApp?.codeText ?? ""
        let bundleID = UUID()
        let staleItemID = UUID()
        let freshItemID = UUID()

        vm.items.append(CoCaptainTimelineItem(
            id: bundleID,
            content: .reviewBundle(ReviewBundleItem(
                items: [
                    PendingReviewItem(
                        id: staleItemID,
                        targetLabel: "Mini-App CODE",
                        summary: "Stale change",
                        preview: "<h1>Stale</h1>",
                        source: .nodeEdit(
                            role: .miniApp,
                            section: .code,
                            operations: [NodePatchOperation(type: .replaceAll, content: "<h1>Stale</h1>")],
                            baseText: baseText
                        )
                    ),
                    PendingReviewItem(
                        id: freshItemID,
                        targetLabel: "Mini-App SRS",
                        summary: "Fresh SRS update",
                        preview: "Fresh SRS",
                        source: .nodeEdit(
                            role: .miniApp,
                            section: .srs,
                            operations: [NodePatchOperation(type: .replaceAll, content: "Fresh SRS")],
                            baseText: miniAppNode.miniApp?.srsText ?? ""
                        )
                    )
                ]
            ))
        ))

        store.updateMiniAppCode(id: miniAppNode.id, text: "<h1>User edited after review</h1>", persist: false)
        vm.applyAll(in: bundleID)

        guard case .reviewBundle(let bundle) = vm.items.first(where: { $0.id == bundleID })?.content else {
            Issue.record("Review bundle missing")
            return
        }

        let stale = bundle.items.first { $0.id == staleItemID }
        let fresh = bundle.items.first { $0.id == freshItemID }
        #expect(stale?.status == .conflicted)
        #expect(fresh?.status == .applied)
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
    @Test func cancelledOnboardingBuildHandoffRecordsFailedCompletion() async throws {
        let coordinator = CoCaptainAgentCoordinator(llmClient: ThrowingLLMClient(error: CancellationError()))
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("I wanna make a pacman game", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(vm.completedAssistantResponseCount == 0)
        #expect(vm.successfulAssistantResponseCount == 0)
        #expect(vm.lastTurnCompletion?.purpose == .onboardingBuildHandoff)
        #expect(vm.lastTurnCompletion?.succeeded == false)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == false)
    }

    @MainActor
    @Test func successfulOnboardingBuildHandoffRecordsTurnCompletion() async throws {
        let llm = TestLLMClient(
            response: "A todo app sounds great. Let's head back to the canvas and start building."
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("I wanna make a pacman game", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(vm.lastTurnCompletion?.purpose == .onboardingBuildHandoff)
        #expect(vm.lastTurnCompletion?.succeeded == true)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == true)
        #expect(llm.receivedPurposes == [.onboardingBuildHandoff])
    }

    @MainActor
    @Test func failedOnboardingBuildHandoffShowsRetryMessageAndFailedCompletion() async throws {
        let llm = TestLLMClient(response: "")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("I wanna make a pacman game", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.lastTurnCompletion?.purpose == .onboardingBuildHandoff)
        #expect(vm.lastTurnCompletion?.succeeded == false)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == false)
        #expect(vm.successfulAssistantResponseCount == 0)
        #expect(vm.items.contains { item in
            guard case .message(let bubble) = item.content else { return false }
            return bubble.text.contains("Please try sending your idea again.")
        })
    }

    @MainActor
    @Test func failedOnboardingBuildHandoffCanRetryWithoutCountingFailureAsSuccess() async throws {
        let llm = FailingThenSucceedingLLMClient(failureCount: 1)
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("I wanna make a pacman game", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 0)
        #expect(vm.lastTurnCompletion?.succeeded == false)

        vm.sendMessage("a todo app again", purpose: .onboardingBuildHandoff)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.completedAssistantResponseCount == 2)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(vm.lastTurnCompletion?.purpose == .onboardingBuildHandoff)
        #expect(vm.lastTurnCompletion?.succeeded == true)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == true)
        #expect(llm.receivedPurposes.allSatisfy { $0 == .onboardingBuildHandoff })
    }

    @MainActor
    @Test func standardTurnCompletionDoesNotAdvanceToCanvasDismissal() async throws {
        let llm = TestLLMClient(response: "Here is how I can help.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)

        vm.sendMessage("help me", purpose: .standard)

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(vm.lastTurnCompletion?.purpose == .standard)
        #expect(vm.lastTurnCompletion?.succeeded == true)
        #expect(vm.lastTurnCompletion?.shouldAdvanceToCanvasDismissal == false)
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

    @Test func parserExtractsActionAttributesFromXML() throws {
        let parser = CoCaptainAgentParser()
        let response =
            """
            <cocaptain_actions>
              <assistant_message>Navigate home.</assistant_message>
              <pending_actions>
                <action id="goRoot" label="home"/>
              </pending_actions>
            </cocaptain_actions>
            """

        let parsed = try #require(parser.parse(response).payload)
        #expect(parsed.pendingActions.count == 1)
        #expect(parsed.pendingActions[0].actionID == "goRoot")
        #expect(parsed.pendingActions[0].args?["label"] == "home")
    }

    @Test func commandIntentResolverRejectsNegatedInput() {
        let resolver = CommandIntentResolver()
        let actions = [
            AppActionDefinition(
                id: .goRoot,
                title: "Go to Root",
                icon: "house.fill",
                category: .navigation,
                isMutating: false,
                allowsAutonomousExecution: true
            )
        ]

        #expect(resolver.resolve("don't go home", availableActions: actions) == nil)
        #expect(resolver.resolve("go home", availableActions: actions) == .goRoot)
    }

    @MainActor
    @Test func coordinatorDoesNotRetryAgenticWorkForNegatedRequests() async throws {
        let llm = TestLLMClient(
            response:
                """
                Sure, I will not change anything.

                <cocaptain_actions>
                  <assistant_message>Sure, I will not change anything.</assistant_message>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        _ = try await coordinator.run(
            userMessage: "don't fix anything please",
            store: makeStore(),
            dispatcher: TestActionDispatcher()
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
    }

    @MainActor
    @Test func coordinatorSurfacesUnknownPendingActionsAsConflictedReview() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = TestLLMClient(
            response:
                """
                <cocaptain_actions>
                  <assistant_message>Pending unknown action.</assistant_message>
                  <pending_actions><action id="launch_rocket"/></pending_actions>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "create a rocket",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(result.reviewBundle?.items.count == 1)
        #expect(result.reviewBundle?.items.first?.status == .conflicted)
        #expect(result.reviewBundle?.items.first?.preview.contains("launch_rocket") == true)
    }

    @MainActor
    @Test func connectionFallbackStagesReviewWithoutExecutingSafeActions() async throws {
        let dispatcher = TestActionDispatcher()
        let llm = FailingThenStructuredLLMClient(
            structuredResponse:
                """
                <cocaptain_actions>
                  <assistant_message>Fallback edit.</assistant_message>
                  <safe_actions><action id="goRoot"/></safe_actions>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update heading">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Fallback</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "update the code",
            store: makeStore(),
            dispatcher: dispatcher
        ) { _ in }

        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.reviewBundle?.items.first?.status == .pending)
        #expect(result.reviewBundle?.items.first?.preview.contains("Fallback") == true)
    }

    @MainActor
    @Test func connectionFallbackShowsDegradedNoticeWhenExecutableWorkMissing() async throws {
        let llm = FailingThenPlainLLMClient(fallbackResponse: "I can explain the idea, but I cannot apply changes right now.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "build a landing page",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(result.reviewBundle == nil)
        #expect(
            result.visibleText.contains(
                LocalizationManager.shared.localizedString("cocaptain.fallback.editsUnavailable")
            )
        )
    }

    @MainActor
    @Test func connectionFallbackOmitsDegradedNoticeForAskTurns() async throws {
        let llm = FailingThenPlainLLMClient(fallbackResponse: "Here are three ideas to explore next.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .ask)

        let result = try await coordinator.run(
            userMessage: "suggest three useful next improvements",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(
            !result.visibleText.contains(
                LocalizationManager.shared.localizedString("cocaptain.fallback.editsUnavailable")
            )
        )
    }

    @Test func chatModeStorageKeyAndComposerCopyAreStable() {
        #expect(CoCaptainChatMode.storageKey == "cocaptain.chatMode")
        #expect(CoCaptainChatMode(rawValue: "agent") == .agent)
        #expect(CoCaptainChatMode(rawValue: "ask") == .ask)
        #expect(CoCaptainChatMode(rawValue: "plan") == nil)
        #expect(CoCaptainChatMode.agent.composerPlaceholder == LocalizationManager.shared.localizedString("cocaptain.composer.placeholder.agent"))
        #expect(CoCaptainChatMode.ask.composerPlaceholder == LocalizationManager.shared.localizedString("cocaptain.composer.placeholder.ask"))
        #expect(CoCaptainChatMode.agent.displayName == LocalizationManager.shared.localizedString("Agent"))
        #expect(CoCaptainChatMode.ask.displayName == LocalizationManager.shared.localizedString("Ask"))
    }

    @MainActor
    @Test func askModeNeverStagesReviewFromStructuredModelOutput() async throws {
        let llm = TestLLMClient(
            response: """
            Here is advice.

            <cocaptain_actions>
              <assistant_message>Renamed the title.</assistant_message>
              <safe_actions><action id="goRoot"/></safe_actions>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Rename title">
                  <operation type="replace_all">
                    <content><![CDATA[<html><body><h1>Should Not Stage</h1></body></html>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let dispatcher = TestActionDispatcher()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .ask)

        let result = try await coordinator.run(
            userMessage: "rename the title to Cafe Menu",
            store: makeStore(),
            dispatcher: dispatcher,
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedExpectsStructuredResponse == [false])
        #expect(llm.receivedAvailableActionCounts == [0])
        #expect(llm.receivedToolExecutorPresence == [false])
        #expect(llm.receivedChatModes == [.ask])
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(result.reviewBundle == nil)
        #expect(result.executionSummary == nil)
        #expect(result.clarifyingQuestion == nil)
        #expect(result.visibleText.contains("Here is advice"))
        #expect(!result.visibleText.contains("Should Not Stage"))
    }

    @MainActor
    @Test func askModeUsesProductContextAndAskPromptPosture() async throws {
        let store = makeStore()
        store.nodes[0].miniApp?.firebaseConfigText = #"{"apiKey":"test"}"#
        let llm = TestLLMClient(response: "Try clarifying the main user goal first.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .ask)

        _ = try await coordinator.run(
            userMessage: "what should we improve next?",
            store: store,
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        let context = try #require(llm.receivedContexts.first ?? nil)
        #expect(context.contains("SRS Readiness:"))
        #expect(!context.contains("Mini-App Firebase wiring rules"))
        #expect(!context.contains("__caocapFirestore"))
        #expect(!context.contains("Firebase Config:"))

        let askPrompt = LLMService.shared.buildPrompt(
            userMessage: "what should we improve next?",
            context: context,
            expectsStructuredResponse: false,
            availableActions: TestActionDispatcher().availableActions,
            scope: .project,
            purpose: .standard,
            chatMode: .ask
        )
        #expect(askPrompt.contains("Ask mode objective:"))
        #expect(askPrompt.contains("Do not request app actions"))
        #expect(!askPrompt.contains("Agent contract:"))
    }

    @MainActor
    @Test func askModeSkipsMutatingDirectCommandShortCircuit() async throws {
        let llm = TestLLMClient(response: "Creating a Mini-App changes the canvas; here is how to think about it first.")
        let dispatcher = TestActionDispatcher()
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let vm = CoCaptainViewModel(agentCoordinator: coordinator)
        vm.store = makeStore()
        vm.actionDispatcher = dispatcher
        vm.chatMode = .ask

        vm.sendMessage("create mini-app")

        for _ in 0..<20 where vm.isThinking {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!vm.isThinking)
        #expect(dispatcher.executedActionIDs.isEmpty)
        #expect(vm.pendingReviewCount == 0)
        #expect(llm.receivedMessages == ["create mini-app"])
        #expect(llm.receivedChatModes == [.ask])
        #expect(llm.receivedExpectsStructuredResponse == [false])
        #expect(
            vm.items.contains { item in
                guard case .message(let bubble) = item.content, !bubble.isUser else { return false }
                return bubble.text.contains("Creating a Mini-App")
            }
        )
    }

    @MainActor
    @Test func askModeStillAllowsNonMutatingAutonomousDirectCommands() async throws {
        let dispatcher = TestActionDispatcher()
        let vm = CoCaptainViewModel()
        vm.actionDispatcher = dispatcher
        vm.chatMode = .ask

        vm.sendMessage("open settings")

        #expect(vm.completedAssistantResponseCount == 1)
        #expect(vm.successfulAssistantResponseCount == 1)
        #expect(dispatcher.executedActionIDs == [.openSettings])
        #expect(vm.pendingReviewCount == 0)
    }

    @MainActor
    @Test func agentPureProseResponseDoesNotRetry() async throws {
        let llm = TestLLMClient(response: "Here are three ideas to explore next.")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "what should we build?",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewBundle == nil)
        #expect(result.visibleText.contains("three ideas"))
    }

    @MainActor
    @Test func agentStagesReviewFromStructuredEditWithoutMutatingVerbs() async throws {
        let llm = TestLLMClient(
            response: """
            <cocaptain_actions>
              <assistant_message>Renamed the title.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Rename title">
                  <operation type="replace_all">
                    <content><![CDATA[<html><body><h1>Cafe Menu</h1></body></html>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "the title should be Cafe Menu",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 1)
        #expect(result.reviewBundle?.items.first?.status == .pending)
        #expect(result.reviewBundle?.items.first?.preview.contains("Cafe Menu") == true)
    }

    @MainActor
    @Test func agentInvalidStructuredPayloadStillRetries() async throws {
        let llm = TestLLMClient(
            responses: [
                """
                <cocaptain_actions>
                  <assistant_message>Broken edit.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Broken</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """,
                """
                <cocaptain_actions>
                  <assistant_message>Fixed heading.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update heading">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Retry</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "rename the title",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(result.reviewBundle?.items.first?.status == .pending)
        #expect(result.reviewBundle?.items.first?.preview.contains("Retry") == true)
    }

    @MainActor
    @Test func onboardingGuidedEditChatOnlyResponseTriggersRetry() async throws {
        let llm = TestLLMClient(
            responses: [
                "I can describe the landing page in chat.",
                """
                <cocaptain_actions>
                  <assistant_message>Updated heading.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Update heading">
                      <operation type="replace_all">
                        <content><![CDATA[<h1>Retry</h1>]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .onboardingGuidedEdit, mode: .agent)

        _ = try await coordinator.run(
            userMessage: "rename the title to Hello CAOCAP",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            purpose: .onboardingGuidedEdit,
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages[1].contains("cocaptain_actions"))
    }

    @MainActor
    @Test func onboardingWelcomeStaysConversational() async throws {
        let llm = TestLLMClient(
            response: """
            Welcome! I help you build apps.
            <cocaptain_actions>
              <assistant_message>Should be ignored.</assistant_message>
              <node_edits>
                <node_edit role="miniApp" section="code" summary="Ignored">
                  <operation type="replace_all">
                    <content><![CDATA[<h1>Nope</h1>]]></content>
                  </operation>
                </node_edit>
              </node_edits>
            </cocaptain_actions>
            """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let turnPlan = CoCaptainTurnPlan(purpose: .onboardingWelcome, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "hi",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            purpose: .onboardingWelcome,
            turnPlan: turnPlan
        ) { _ in }

        #expect(result.reviewBundle == nil)
        #expect(llm.receivedMessages.count == 1)
    }

    @MainActor
    @Test func nodeScopedReviewBundleReloadsFromPersistedNodeState() throws {
        let store = makeStore()
        let nodeID = store.nodes[0].id
        let bundleID = UUID()
        let reviewBundle = ReviewBundleItem(
            items: [
                PendingReviewItem(
                    targetLabel: "Mini-App CODE",
                    summary: "Update heading",
                    preview: "<h1>Persisted</h1>",
                    source: .nodeEdit(
                        role: .miniApp,
                        section: .code,
                        operations: [NodePatchOperation(type: .replaceAll, content: "<h1>Persisted</h1>")],
                        baseText: store.nodes[0].miniApp?.codeText ?? ""
                    )
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let record = NodeAgentReviewRecord(timelineItemID: bundleID, bundle: reviewBundle)
        var agentState = store.nodes[0].agentState
        agentState.pendingReviewBundlesData = [try encoder.encode(record)]
        store.updateNodeAgentState(id: nodeID, agentState: agentState, persist: false)

        let vm = CoCaptainViewModel()
        vm.configureNodeSession(store: store, nodeID: nodeID)

        #expect(vm.items.contains { item in
            guard item.id == bundleID,
                  case .reviewBundle(let bundle) = item.content else { return false }
            return bundle.items.first?.preview.contains("Persisted") == true
        })
    }

    @MainActor
    @Test func forgivingStagingAcceptsLooseReplaceExact() async throws {
        let llm = TestLLMClient(
            response: looseHeadlineEditResponse(replacement: "hello azzam", target: "hello world")
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "change hello world to hello azzam",
            store: makeStore(),
            dispatcher: nil
        ) { _ in }

        let item = try #require(result.reviewBundle?.items.first)
        #expect(item.status == .pending)
        guard case .nodeEdit(_, _, let operations, _) = item.source else {
            Issue.record("Expected node edit review item")
            return
        }
        #expect(operations.count == 1)
        #expect(operations.first?.type == .replaceAll)
        #expect(item.preview.contains("hello azzam"))
    }

    @MainActor
    @Test func codeEditWithoutChecksStagesReview() async throws {
        let llm = TestLLMClient(
            response:
                """
                <cocaptain_actions>
                  <assistant_message>Renamed the heading.</assistant_message>
                  <node_edits>
                    <node_edit role="miniApp" section="code" summary="Rename heading">
                      <operation type="replace_exact">
                        <target>Hello World!</target>
                        <content><![CDATA[hi azzam]]></content>
                      </operation>
                    </node_edit>
                  </node_edits>
                </cocaptain_actions>
                """
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "Rename the title from hello world to hi azzam",
            store: makeStore(),
            dispatcher: nil
        ) { _ in }

        let item = try #require(result.reviewBundle?.items.first)
        #expect(item.status == .pending)
        #expect(item.preview.contains("hi azzam"))
        #expect(result.clarifyingQuestion == nil)
    }

    @Test func parserExtractsClarifyingQuestion() {
        let parser = CoCaptainAgentParser()
        let response = """
        Let me make sure I understand.
        <cocaptain_actions>
          <assistant_message>Happy to help!</assistant_message>
          <clarifying_question prompt="What kind of change did you have in mind?">
            <option>Make the colors brighter</option>
            <option>Make the text bigger</option>
            <option>Add a fun animation</option>
          </clarifying_question>
        </cocaptain_actions>
        """

        let parsed = parser.parse(response)
        let question = parsed.payload?.clarifyingQuestion

        #expect(question?.prompt == "What kind of change did you have in mind?")
        #expect(question?.options == [
            "Make the colors brighter",
            "Make the text bigger",
            "Add a fun animation"
        ])
    }

    @Test func parserDropsMalformedClarifyingQuestion() {
        let parser = CoCaptainAgentParser()
        let response = """
        <cocaptain_actions>
          <assistant_message>Hmm.</assistant_message>
          <clarifying_question prompt="Only one option?">
            <option>Just this</option>
          </clarifying_question>
        </cocaptain_actions>
        """

        let parsed = parser.parse(response)

        #expect(parsed.payload?.clarifyingQuestion == nil)
        #expect(parsed.payload?.assistantMessage == "Hmm.")
    }

    @MainActor
    @Test func validatorAcceptsQuestionOnlyPayloadAsAgenticWork() {
        let validator = CoCaptainAgentValidator()
        let payload = CoCaptainAgentPayload(
            assistantMessage: "Quick question first.",
            clarifyingQuestion: CoCaptainClarifyingQuestion(
                prompt: "Which one did you mean?",
                options: ["The heading", "The button"]
            )
        )

        let result = validator.validate(
            payload: payload,
            dispatcher: nil,
            requiresAgenticWork: true
        )

        #expect(result.isValid)
    }

    @MainActor
    @Test func coordinatorReturnsClarifyingQuestionAndDropsAccompanyingEdits() async throws {
        let response = """
        <cocaptain_actions>
          <assistant_message>Before I change anything, one question.</assistant_message>
          <clarifying_question prompt="Which look do you want?">
            <option>Bright and playful</option>
            <option>Dark and sleek</option>
          </clarifying_question>
          <node_edits>
            <node_edit role="miniApp" section="code" summary="Update heading">
              <operation type="replace_exact">
                <target>Hello World!</target>
                <content><![CDATA[hi]]></content>
              </operation>
            </node_edit>
          </node_edits>
        </cocaptain_actions>
        """
        let llm = TestLLMClient(response: response)
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "change the look of my app",
            store: makeStore(),
            dispatcher: nil
        ) { _ in }

        #expect(result.clarifyingQuestion?.prompt == "Which look do you want?")
        #expect(result.clarifyingQuestion?.options.count == 2)
        #expect(result.reviewBundle == nil)
    }

    @MainActor
    @Test func ambiguousEditStagesNeedsClarificationItem() async throws {
        let llm = TestLLMClient(
            response: looseHeadlineEditResponse(replacement: "hi azzam", target: "Hello World!")
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let store = makeAmbiguousStore()

        let result = try await coordinator.run(
            userMessage: "change Hello World! to hi azzam",
            store: store,
            dispatcher: nil
        ) { _ in }

        let item = try #require(result.reviewBundle?.items.first)
        #expect(item.status == .needsClarification)
        #expect(item.clarificationCandidates?.count == 2)
        guard case .nodeEdit(_, _, _, let baseText) = item.source else {
            Issue.record("Expected node edit review item")
            return
        }
        #expect(!baseText.isEmpty)
    }

    @MainActor
    @Test func validationFailureOffersRecoveryQuestion() async throws {
        // A persistently invalid payload (empty summary) exhausts retries and
        // lands in the validation failure path, which must offer a next step.
        let invalidResponse = """
        <cocaptain_actions>
          <assistant_message>Done!</assistant_message>
          <node_edits>
            <node_edit role="miniApp" section="code" summary="">
              <operation type="replace_exact">
                <target>Hello World!</target>
                <content><![CDATA[hi]]></content>
              </operation>
            </node_edit>
          </node_edits>
        </cocaptain_actions>
        """
        let llm = TestLLMClient(response: invalidResponse)
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "build a landing page",
            store: makeStore(),
            dispatcher: nil
        ) { _ in }

        #expect(result.clarifyingQuestion != nil)
        #expect(result.clarifyingQuestion?.options.isEmpty == false)
        #expect(result.reviewBundle == nil)
    }

    @MainActor
    @Test func resolveClarificationRestagesChosenCandidateLocally() async throws {
        let llm = TestLLMClient(
            response: looseHeadlineEditResponse(replacement: "hi azzam", target: "Hello World!")
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let store = makeAmbiguousStore()
        let viewModel = CoCaptainViewModel(agentCoordinator: coordinator)
        viewModel.configureProjectSession(store: store, dispatcher: nil)

        let result = try await coordinator.run(
            userMessage: "change Hello World! to hi azzam",
            store: store,
            dispatcher: nil
        ) { _ in }

        let bundle = try #require(result.reviewBundle)
        let bundleItem = CoCaptainTimelineItem(content: .reviewBundle(bundle))
        viewModel.items.append(bundleItem)

        let pendingItem = try #require(bundle.items.first)
        let candidate = try #require(pendingItem.clarificationCandidates?.first)
        viewModel.resolveClarification(
            bundleID: bundleItem.id,
            itemID: pendingItem.id,
            candidateID: candidate.id
        )

        guard case .reviewBundle(let updatedBundle) = viewModel.items.last?.content,
              let updatedItem = updatedBundle.items.first else {
            Issue.record("Expected an updated review bundle")
            return
        }
        #expect(updatedItem.status == .pending)
        #expect(updatedItem.clarificationCandidates == nil)
        #expect(updatedItem.preview.contains("hi azzam"))
        guard case .nodeEdit(_, _, let operations, _) = updatedItem.source else {
            Issue.record("Expected node edit review item")
            return
        }
        #expect(operations.first?.type == .replaceAll)
    }

    @MainActor
    @Test func answeringClarifyingQuestionLocksCardAndSendsOption() throws {
        let llm = TestLLMClient(response: "Nice choice!")
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)
        let viewModel = CoCaptainViewModel(agentCoordinator: coordinator)
        viewModel.configureProjectSession(store: nil, dispatcher: nil)

        let questionItem = CoCaptainClarifyingQuestionItem(
            question: CoCaptainClarifyingQuestion(
                prompt: "What should we improve?",
                options: ["Make the text bigger", "Change the colors"]
            )
        )
        let timelineItem = CoCaptainTimelineItem(content: .clarifyingQuestion(questionItem))
        viewModel.items.append(timelineItem)

        viewModel.answerClarifyingQuestion(itemID: timelineItem.id, option: "Change the colors")

        guard let index = viewModel.items.firstIndex(where: { $0.id == timelineItem.id }),
              case .clarifyingQuestion(let answered) = viewModel.items[index].content else {
            Issue.record("Expected the clarifying question item to remain")
            return
        }
        #expect(answered.answeredOption == "Change the colors")

        let sentUserMessage = viewModel.items.contains { item in
            guard case .message(let bubble) = item.content else { return false }
            return bubble.isUser && bubble.text == "Change the colors"
        }
        #expect(sentUserMessage)

        // A second tap must not re-send.
        viewModel.answerClarifyingQuestion(itemID: timelineItem.id, option: "Make the text bigger")
        guard case .clarifyingQuestion(let stillAnswered) = viewModel.items[index].content else {
            Issue.record("Expected the clarifying question item to remain")
            return
        }
        #expect(stillAnswered.answeredOption == "Change the colors")
    }

    // MARK: - Phase 3: node edits via function calling

    @Test func nodeEditFunctionAdapterMapsProposeNodeEdit() throws {
        let adapter = CoCaptainNodeEditFunctionAdapter()
        let nodeID = UUID()

        let directive = adapter.directive(
            from: [
                CoCaptainAgentFunctionCall(
                    name: CoCaptainNodeEditTools.proposeNodeEditName,
                    arguments: [
                        "nodeId": .string(nodeID.uuidString),
                        "section": "code",
                        "summary": "Update the heading",
                        "operations": [
                            [
                                "type": "replace_exact",
                                "target": "Hello World!",
                                "content": "Hello CAOCAP!"
                            ]
                        ],
                        "learningNote": [
                            "concept": "Exact text replacement",
                            "body": "Your heading changed because the edit found the old text and swapped it in place."
                        ]
                    ]
                )
            ],
            visibleText: "I prepared an edit."
        )

        let edit = try #require(directive.payload?.nodeEdits.first)
        #expect(edit.nodeID == nodeID)
        #expect(edit.section == .code)
        #expect(edit.summary == "Update the heading")
        #expect(edit.operations.first?.type == .replaceExact)
        #expect(edit.operations.first?.target == "Hello World!")
        #expect(edit.operations.first?.content == "Hello CAOCAP!")
        #expect(edit.learningNote?.concept == "Exact text replacement")
        #expect(directive.diagnostics.isEmpty)
        #expect(directive.source == .nodeEditFunctionCall)
    }

    @Test func nodeEditFunctionAdapterReportsMalformedArguments() throws {
        let adapter = CoCaptainNodeEditFunctionAdapter()

        let missingSummary = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainNodeEditTools.proposeNodeEditName,
                arguments: [
                    "operations": [["type": "append", "content": "<p>hi</p>"]]
                ]
            )
        ])
        let malformedOperation = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainNodeEditTools.proposeNodeEditName,
                arguments: [
                    "summary": "Broken op",
                    "operations": [["type": "not_a_real_type", "content": "x"]]
                ]
            )
        ])

        #expect(missingSummary.payload == nil)
        #expect(missingSummary.diagnostics.first?.contains("summary") == true)
        #expect(malformedOperation.payload == nil)
        #expect(malformedOperation.diagnostics.first?.contains("malformed operation") == true)
    }

    @Test func nodeEditFunctionAdapterDegradesMalformedLearningNote() throws {
        let adapter = CoCaptainNodeEditFunctionAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainNodeEditTools.proposeNodeEditName,
                arguments: [
                    "summary": "Update heading",
                    "operations": [["type": "append", "content": "<p>hi</p>"]],
                    "learningNote": ["concept": "   ", "body": ""]
                ]
            )
        ])

        let edit = try #require(directive.payload?.nodeEdits.first)
        #expect(edit.learningNote == nil)
        #expect(directive.diagnostics.isEmpty)
    }

    @Test func nodeEditFunctionAdapterMapsClarifyingQuestion() throws {
        let adapter = CoCaptainNodeEditFunctionAdapter()

        let directive = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainNodeEditTools.askClarifyingQuestionName,
                arguments: [
                    "prompt": "Which look do you want?",
                    "options": ["Bright and playful", "Dark and sleek"]
                ]
            )
        ])

        #expect(directive.payload?.clarifyingQuestion?.prompt == "Which look do you want?")
        #expect(directive.payload?.clarifyingQuestion?.options.count == 2)
        #expect(directive.payload?.nodeEdits.isEmpty == true)

        let tooFewOptions = adapter.directive(from: [
            CoCaptainAgentFunctionCall(
                name: CoCaptainNodeEditTools.askClarifyingQuestionName,
                arguments: ["prompt": "Vague?", "options": ["Only one"]]
            )
        ])
        #expect(tooFewOptions.payload == nil)
        #expect(tooFewOptions.diagnostics.isEmpty == false)
    }

    @Test func compositeAdapterPrefersFunctionCallEditsOverXMLEdits() throws {
        let adapter = CoCaptainCompositeAgentAdapter()
        let response = """
        I prepared an edit.

        <cocaptain_actions>
          <assistant_message>I prepared an edit.</assistant_message>
          <node_edits>
            <node_edit role="miniApp" section="code" summary="XML edit">
              <operation type="replace_all">
                <content><![CDATA[<h1>From XML</h1>]]></content>
              </operation>
            </node_edit>
          </node_edits>
        </cocaptain_actions>
        """

        let directive = adapter.directive(
            from: response,
            functionCalls: [
                CoCaptainAgentFunctionCall(
                    name: CoCaptainNodeEditTools.proposeNodeEditName,
                    arguments: [
                        "summary": "Tool edit",
                        "operations": [["type": "replace_all", "content": "<h1>From tool</h1>"]]
                    ]
                )
            ]
        )

        #expect(directive.payload?.nodeEdits.count == 1)
        #expect(directive.payload?.nodeEdits.first?.summary == "Tool edit")
        #expect(directive.source == .combined)
    }

    @Test func compositeAdapterReportsNodeEditFunctionCallSource() throws {
        let adapter = CoCaptainCompositeAgentAdapter()

        let directive = adapter.directive(
            from: "I prepared an edit.",
            functionCalls: [
                CoCaptainAgentFunctionCall(
                    name: CoCaptainNodeEditTools.proposeNodeEditName,
                    arguments: [
                        "summary": "Tool edit",
                        "operations": [["type": "append", "content": "<p>hi</p>"]]
                    ]
                )
            ]
        )

        #expect(directive.payload?.nodeEdits.first?.summary == "Tool edit")
        #expect(directive.source == .nodeEditFunctionCall)
    }

    @MainActor
    @Test func coordinatorStagesFunctionCalledNodeEditForReview() async throws {
        let store = makeStore()
        let nodeID = store.nodes[0].id
        let llm = TestLLMClient(
            response: "I prepared an edit for your review.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainNodeEditTools.proposeNodeEditName,
                    arguments: [
                        "nodeId": .string(nodeID.uuidString),
                        "section": "code",
                        "summary": "Update the heading",
                        "operations": [
                            ["type": "replace_all", "content": "<h1>From tool</h1>"]
                        ],
                        "learningNote": [
                            "concept": "Full rebuild",
                            "body": "Replacing the whole document keeps the page consistent in one step."
                        ]
                    ]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "change the heading",
            store: store,
            dispatcher: nil
        ) { _ in }

        let item = try #require(result.reviewBundle?.items.first)
        #expect(item.status == .pending)
        #expect(item.targetNodeID == nodeID)
        #expect(item.learningNote?.concept == "Full rebuild")
        // Human-in-the-loop guard: staging must never touch the live node.
        #expect(store.nodes[0].miniApp?.codeText.contains("From tool") == false)
    }

    @MainActor
    @Test func functionCalledClarifyingQuestionBeatsFunctionCalledEdits() async throws {
        let llm = TestLLMClient(
            response: "One question first.",
            functionCalls: [[
                CoCaptainAgentFunctionCall(
                    name: CoCaptainNodeEditTools.askClarifyingQuestionName,
                    arguments: [
                        "prompt": "Which look do you want?",
                        "options": ["Bright and playful", "Dark and sleek"]
                    ]
                ),
                CoCaptainAgentFunctionCall(
                    name: CoCaptainNodeEditTools.proposeNodeEditName,
                    arguments: [
                        "summary": "Guessy restyle",
                        "operations": [["type": "replace_all", "content": "<h1>Guess</h1>"]]
                    ]
                )
            ]]
        )
        let coordinator = CoCaptainAgentCoordinator(llmClient: llm)

        let result = try await coordinator.run(
            userMessage: "change the look",
            store: makeStore(),
            dispatcher: nil
        ) { _ in }

        #expect(result.clarifyingQuestion?.prompt == "Which look do you want?")
        #expect(result.reviewBundle == nil)
    }

    @MainActor
    @Test func agenticRetryReferencesToolsWhenNodeEditToolsEnabled() async throws {
        // Agent retries on invalid structured output, not on missing edits.
        let llm = TestLLMClient(
            responses: [
                "Broken first attempt.",
                "Here is the edit."
            ],
            functionCalls: [
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainNodeEditTools.proposeNodeEditName,
                        arguments: [
                            "summary": "",
                            "operations": [["type": "replace_all", "content": "<h1>Broken</h1>"]]
                        ]
                    )
                ],
                [
                    CoCaptainAgentFunctionCall(
                        name: CoCaptainNodeEditTools.proposeNodeEditName,
                        arguments: [
                            "summary": "Build the landing page",
                            "operations": [["type": "replace_all", "content": "<h1>Landing</h1>"]]
                        ]
                    )
                ]
            ]
        )
        let coordinator = CoCaptainAgentCoordinator(
            llmClient: llm,
            nodeEditToolsEnabled: { true }
        )
        let turnPlan = CoCaptainTurnPlan(purpose: .standard, mode: .agent)

        let result = try await coordinator.run(
            userMessage: "build a landing page",
            store: makeStore(),
            dispatcher: TestActionDispatcher(),
            turnPlan: turnPlan
        ) { _ in }

        #expect(llm.receivedMessages.count == 2)
        #expect(llm.receivedMessages[1].contains("propose_node_edit"))
        #expect(llm.receivedMessages[1].contains("cocaptain_actions") == false)
        #expect(result.reviewBundle?.items.first?.status == .pending)
    }

    @MainActor
    @Test func buildPromptSwitchesContractWithNodeEditToolsFlag() {
        func prompt(toolsEnabled: Bool) -> String {
            LLMService.shared.buildPrompt(
                userMessage: "build a landing page",
                context: "Canvas context",
                expectsStructuredResponse: true,
                availableActions: [],
                scope: .project,
                purpose: .standard,
                chatMode: .agent,
                nodeEditToolsEnabled: toolsEnabled
            )
        }

        let toolsPrompt = prompt(toolsEnabled: true)
        #expect(toolsPrompt.contains("propose_node_edit"))
        #expect(toolsPrompt.contains("ask_clarifying_question"))
        #expect(toolsPrompt.contains("cocaptain_actions") == false)

        let xmlPrompt = prompt(toolsEnabled: false)
        #expect(xmlPrompt.contains("XML schema for `cocaptain_actions`"))
        #expect(xmlPrompt.contains("<learning_note"))
        #expect(xmlPrompt.contains("propose_node_edit") == false)
    }

    @MainActor
    private func makeAmbiguousStore() -> ProjectStore {
        ProjectStore(
            fileName: "ambiguous-test-\(UUID().uuidString).json",
            projectName: "Test Project",
            initialNodes: [
                SpatialNode(
                    type: .miniApp,
                    position: CGPoint(x: 0, y: 0),
                    title: "Mini-App",
                    theme: .blue,
                    miniApp: MiniAppState(
                        srsText: "Build a landing page",
                        codeText: """
                        <html><body>
                        <h1>Hello World!</h1>
                        <p>Hello World!</p>
                        </body></html>
                        """
                    )
                )
            ]
        )
    }

    private func looseHeadlineEditResponse(replacement: String, target: String) -> String {
        """
        <cocaptain_actions>
          <assistant_message>Changed the heading.</assistant_message>
          <node_edits>
            <node_edit role="miniApp" section="code" summary="Update heading">
              <operation type="replace_exact">
                <target>\(target)</target>
                <content><![CDATA[\(replacement)]]></content>
              </operation>
            </node_edit>
          </node_edits>
        </cocaptain_actions>
        """
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
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
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
    var receivedChatModes: [CoCaptainChatMode] = []
    var receivedExpectsStructuredResponse: [Bool] = []
    var receivedAvailableActionCounts: [Int] = []
    var receivedContexts: [String?] = []
    var receivedToolExecutorPresence: [Bool] = []

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
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        receivedMessages.append(userMessage)
        receivedScopes.append(scope)
        receivedPurposes.append(purpose)
        receivedChatModes.append(chatMode)
        receivedExpectsStructuredResponse.append(expectsStructuredResponse)
        receivedAvailableActionCounts.append(availableActions.count)
        receivedContexts.append(context)
        receivedToolExecutorPresence.append(toolExecutor != nil)
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

/// Simulates the LLMService tool loop: emits one tool call, answers it through
/// the injected executor when possible, then streams the final response text.
/// Calls the executor declines (returns `nil` for) are yielded as
/// `.functionCalls` events, mirroring the real collect-and-route behavior.
@MainActor
private final class ToolLoopLLMClient: CoCaptainLLMClient {
    private let toolCall: CoCaptainAgentFunctionCall
    private let finalResponse: String
    private(set) var capturedToolResults: [String] = []

    init(toolCall: CoCaptainAgentFunctionCall, finalResponse: String) {
        self.toolCall = toolCall
        self.finalResponse = finalResponse
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        let call = toolCall
        let response = finalResponse
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                if let toolExecutor, let result = await toolExecutor(call) {
                    self.capturedToolResults.append(result)
                } else {
                    continuation.yield(.functionCalls([call]))
                }
                continuation.yield(.text(response))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
private final class FailingThenPlainLLMClient: CoCaptainLLMClient {
    private let fallbackResponse: String

    init(fallbackResponse: String) {
        self.fallbackResponse = fallbackResponse
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        if expectsStructuredResponse, context != nil {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: NSError(
                        domain: "CoCaptainFallbackTest",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Structured request failed"]
                    )
                )
            }
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.text(fallbackResponse))
            continuation.finish()
        }
    }
}

@MainActor
private final class FailingThenStructuredLLMClient: CoCaptainLLMClient {
    private let structuredResponse: String

    init(structuredResponse: String) {
        self.structuredResponse = structuredResponse
    }

    func resetChat(scope: CoCaptainAgentScope) {}

    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        if expectsStructuredResponse, context != nil {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: NSError(
                        domain: "CoCaptainFallbackTest",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Structured request failed"]
                    )
                )
            }
        }

        return AsyncThrowingStream { continuation in
            continuation.yield(.text(structuredResponse))
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
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode = .agent,
        toolExecutor: CoCaptainToolExecutor? = nil
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
            id: .help,
            title: "Help",
            icon: "questionmark.circle",
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
