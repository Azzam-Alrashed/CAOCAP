import SwiftUI
import UniformTypeIdentifiers
import OSLog

/// Notification names used to post app-level commands through `NotificationCenter`.
/// This pattern lets hardware-keyboard `.commands` (iPadOS/macCatalyst) and
/// hidden zero-size buttons (iPhone, where `.commands` is ignored) all funnel
/// into the same action bus without coupling the sources to the view.
extension Notification.Name {
    static let openCommandPalette = Notification.Name("openCommandPalette")
    static let summonCoCaptain = Notification.Name("summonCoCaptain")
    static let performUndo = Notification.Name("performUndo")
    static let performRedo = Notification.Name("performRedo")
}

/// Root view that owns the entire session state.
///
/// `ContentView` sits directly inside the `WindowGroup` and is responsible for:
/// - Rendering the active `InfiniteCanvasView` based on `AppRouter.currentWorkspace`.
/// - Hosting the floating command button, command palette overlay, and CoCaptain sheet.
/// - Bridging the undo/redo stack between `UndoManager` and `ProjectStore`.
/// - Routing `AppActionDispatcher` actions to concrete UI state mutations.
/// - Coordinating the launch screen, intro flow, and onboarding tutorial.
struct ContentView: View {
    /// Global command palette state; injected down to `CommandPaletteView`.
    @State var commandPalette = CommandPaletteViewModel()
    /// CoCaptain assistant panel state; injected down to `CoCaptainView`.
    @State var coCaptain = CoCaptainViewModel()
    /// Central dispatcher that maps action IDs to registered closures.
    @State private var actionDispatcher = AppActionDispatcher()
    /// Drives workspace navigation; owns root and project `ProjectStore` instances.
    @State private var router = AppRouter()
    /// Canvas dot-grid opacity, persisted across launches.
    @AppStorage("grid_opacity") private var gridOpacity: Double = 0.1
    /// Last non-zero grid opacity, stored so toggling the grid off/on restores the prior value.
    @AppStorage("last_grid_opacity") private var lastGridOpacity: Double = 0.1
    /// Whether the heads-up display (viewport info bar) is currently visible.
    @AppStorage("showing_hud") private var showingHUD: Bool = false
    @State private var showingFileImporter = false
    @State private var showingPurchaseSheet = false
    @State private var showingSignIn = false
    @State private var showingSettings = false
    @State private var showingSnapshotBrowser = false
    @State private var showingProfile = false
    /// Tracks the current pinch-to-zoom level of the canvas, mirrored from `ViewportState`.
    @State private var currentScale: CGFloat = 1.0
    @Environment(\.undoManager) var undoManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTheme = "System"
    /// `true` while the animated launch screen is covering the canvas.
    @State private var isLaunching = true
    @State private var appUpdateService = AppUpdateService.shared
    /// Current canvas scroll/zoom state, kept in sync with the active `ProjectStore`.
    @State private var viewport = ViewportState()
    /// Reported rendering frames for each node, used by fly-to animation to calculate target scale.
    @State private var nodeFrames: [UUID: NodeFrameData] = [:]
    /// Snapshot of the geometry container size, updated whenever the window resizes.
    @State private var containerSize: CGSize = .zero
    
    // Export State
    @State private var isExporting = false
    /// URL of the most recently exported bundle, passed to the share sheet.
    @State private var exportURL: URL?
    @State private var showExportSheet = false
    
    // Onboarding
    @State private var intro = IntroCoordinator()
    @State private var onboarding = OnboardingCoordinator()
    /// Active presentation detent for the CoCaptain bottom sheet.
    @State private var coCaptainDetent: PresentationDetent = .medium
    /// When `true`, the sheet opens at `.large` on iPhone for onboarding steps that
    /// require the full-height CoCaptain panel.
    @State private var coCaptainStartsLarge = false
    /// Controls whether the `.medium` detent is available, temporarily locked out when
    /// the sheet must start large during onboarding.
    @State private var coCaptainAllowsMediumDetent = true
    /// The baseline count of successful CoCaptain assistant responses. Used during onboarding to wait
    /// until the assistant successfully responds to the user's initial prompt before advancing the step.
    @State private var onboardingInitialCoCaptainSuccessBaseline: Int?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
            switch router.currentWorkspace {
            case .root:
                InfiniteCanvasView(
                    store: router.rootStore,
                    viewport: $viewport,
                    currentScale: $currentScale,
                    onNodeAction: { action in
                        handleNodeAction(action)
                    },
                    onNavigateToSubCanvas: { fileName in
                        router.navigateToSubCanvas(fileName: fileName)
                    },
                    onRecoverUnsupportedProject: {
                        router.createFreshMiniAppCanvas()
                    }
                )
                .id("root_canvas")
            case .project(let fileName):
                InfiniteCanvasView(
                    store: router.activeStore,
                    viewport: $viewport,
                    currentScale: $currentScale,
                    onNodeAction: { action in
                        handleNodeAction(action)
                    },
                    onNavigateToSubCanvas: { fileName in
                        router.navigateToSubCanvas(fileName: fileName)
                    },
                    onRecoverUnsupportedProject: {
                        router.createFreshMiniAppCanvas()
                    }
                )
                .id("project_canvas_\(fileName)")
            }

            if showingHUD {
                CanvasHUDView(
                    store: router.activeStore,
                    viewportScale: currentScale,
                    onSignInTapped: { showingSignIn = true },
                    onCheckpointsTapped: { showingSnapshotBrowser = true }
                )
            }

            floatingCommandButtonView
            .environment(\.layoutDirection, .leftToRight)

            CommandPaletteView(viewModel: commandPalette)
            
            // Hidden buttons to capture hardware keyboard shortcuts on iOS (where .commands is ignored on iPhone)
            Group {
                Button("") {
                    commandPalette.setPresented(true)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("") {
                    _ = actionDispatcher.perform(.summonCoCaptain, source: .user)
                }
                .keyboardShortcut("j", modifiers: .command)
                
                Button("") {
                    undoManager?.undo()
                    router.activeStore.undoStackChanged += 1
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("") {
                    undoManager?.redo()
                    router.activeStore.undoStackChanged += 1
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            .opacity(0)
            .allowsHitTesting(false)
            .frame(width: 0, height: 0)
        }
        .onboardingTooltipOverlay()
        .background(Color.black.ignoresSafeArea())
        .overlay {
            if isLaunching {
                LaunchScreenView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .overlay {
            if !isLaunching && intro.shouldPresent {
                IntroView(coordinator: intro) {
                    onboarding.startIfNeeded()
                }
                .transition(.opacity)
                .zIndex(80)
            }
        }
        .overlay {
            if let availableUpdate = appUpdateService.availableUpdate,
               appUpdateService.shouldPresentUpdatePrompt,
               !isLaunching {
                AppUpdatePromptView(
                    update: availableUpdate,
                    onUpdate: {}
                )
                .zIndex(90)
            }
        }
        .preferredColorScheme(currentColorScheme)
        .sheet(isPresented: $coCaptain.isPresented) {
            CoCaptainView(viewModel: coCaptain)
                .presentationDetents(coCaptainAvailableDetents, selection: $coCaptainDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground {
                    Color.white.opacity(0.4)
                        .background(.ultraThinMaterial)
                }
                .presentationBackgroundInteraction(.enabled)
                .onAppear {
                    guard coCaptainStartsLarge else { return }
                    Task { @MainActor in
                        await Task.yield()
                        coCaptainAllowsMediumDetent = true
                    }
                }
        }
        .sheet(isPresented: $showingSignIn) {
            SignInView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground {
                    Color.black.opacity(0.95)
                        .background(.ultraThinMaterial)
                }
        }
        .sheet(isPresented: $showingPurchaseSheet) {
            PurchaseView()
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(hex: "050505"))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(onboarding)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSnapshotBrowser) {
            SnapshotBrowserView(store: router.activeStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ActivityView(activityItems: [url])
                    .presentationDetents([.medium, .large])
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Preparing Export...")
                }
                .presentationDetents([.height(200)])
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(onSignIn: {
                showingSignIn = true
            }, onPro: {
                showingPurchaseSheet = true
            })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: router.currentWorkspace) {
            setupCommandHandlers()
        }
        .onAppear {
            setupCommandHandlers()
            configureActionDispatcher()
            setupCommandHandlers()

            viewport = ViewportState(
                offset: router.activeStore.viewportOffset,
                scale: router.activeStore.viewportScale
            )
            currentScale = viewport.scale
            router.activeStore.undoManager = undoManager
            router.rootStore.undoManager = undoManager

            coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)

            // Dismiss launch screen after animation
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLaunching = false
                }
                // Start interactive tutorial after launch, or after intro if it is still pending.
                if !intro.shouldPresent {
                    onboarding.startIfNeeded()
                }
            }
        }
        .task {
            await appUpdateService.checkForUpdate()
        }
        .onChange(of: commandPalette.isPresented) { _, isPresented in
            if isPresented {
                commandPalette.nodes = router.activeStore.nodes
                if onboarding.currentStep == .tapFAB {
                    onboarding.completeCurrentStep()
                }
            } else {
                if onboarding.currentStep == .typeCoCaptainPrompt || onboarding.currentStep == .submitCoCaptainPrompt {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if (onboarding.currentStep == .typeCoCaptainPrompt || onboarding.currentStep == .submitCoCaptainPrompt) && !coCaptain.isPresented {
                            onboarding.moveToStep(.tapFAB)
                        }
                    }
                }
            }
        }
        .onChange(of: coCaptain.isPresented) { _, isPresented in
            if isPresented {
                if onboarding.currentStep == .submitCoCaptainPrompt {
                    onboarding.hidePopoverForCurrentStep()
                }
            } else {
                onboardingInitialCoCaptainSuccessBaseline = nil
                if onboarding.currentStep == .dismissCoCaptain {
                    onboarding.completeCurrentStep()
                } else if onboarding.currentStep == .submitCoCaptainPrompt || onboarding.currentStep == .chatCoCaptain {
                    onboarding.moveToStep(.longPressFAB)
                }
            }
        }
        .onChange(of: coCaptain.successfulAssistantResponseCount) {
            advanceInitialCoCaptainOnboardingIfReady()
        }
        .onChange(of: router.currentWorkspace) {
            router.activeStore.undoManager = undoManager
            coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
            syncCommandPaletteActions()
            commandPalette.nodes = router.activeStore.nodes
            
            // Sync viewport with new store
            viewport = ViewportState(
                offset: router.activeStore.viewportOffset,
                scale: router.activeStore.viewportScale
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in
            router.activeStore.undoStackChanged += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in
            router.activeStore.undoStackChanged += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCommandPalette)) { _ in
            commandPalette.setPresented(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .summonCoCaptain)) { _ in
            _ = actionDispatcher.perform(.summonCoCaptain, source: .user)
        }
        .onReceive(NotificationCenter.default.publisher(for: .performUndo)) { _ in
            undoManager?.undo()
            router.activeStore.undoStackChanged += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .performRedo)) { _ in
            undoManager?.redo()
            router.activeStore.undoStackChanged += 1
        }
        .onPreferenceChange(NodeFramePreferenceKey.self) { value in
            nodeFrames = value
        }
        .onAppear {
            containerSize = geometry.size
        }
        .onChange(of: geometry.size) { _, newSize in
            containerSize = newSize
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, UTType(filenameExtension: "caocap")].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .environment(onboarding)
    }
}

    // MARK: - Floating Command Button

    /// Constructs the floating action button positioned over the canvas.
    /// Wires all FAB interactions (tap, undo, redo, long-press drag) to the action
    /// dispatcher and onboarding coordinator.
    private var floatingCommandButtonView: some View {
        FloatingCommandButton(
            onTap: {
                commandPalette.setPresented(true)
            },
            onUndo: {
                undoManager?.undo()
                router.activeStore.undoStackChanged += 1
            },
            onSummonCoCaptain: {
                _ = actionDispatcher.perform(.summonCoCaptain, source: .user)
            },
            onRedo: {
                undoManager?.redo()
                router.activeStore.undoStackChanged += 1
            },
            canUndo: (router.activeStore.undoStackChanged >= 0) && (undoManager?.canUndo ?? false),
            canRedo: (router.activeStore.undoStackChanged >= 0) && (undoManager?.canRedo ?? false),
            onExpand: {
                if onboarding.currentStep == .longPressFAB {
                    onboarding.completeCurrentStep()
                }
            },
            onDragSummon: {
                if onboarding.currentStep == .longPressFAB {
                    onboarding.completeCurrentStep()
                }
            },
            isOnboardingHighlighted: onboarding.showPopover &&
                (onboarding.currentStep == .tapFAB || onboarding.currentStep == .longPressFAB)
        )
    }
    
    /// Maps the locally stored theme string to a `ColorScheme` override.
    /// Returns `nil` to let the system handle appearance when set to `"System"`.
    private var currentColorScheme: ColorScheme? {
        switch selectedTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    /// Routes `NodeAction` values emitted by canvas node tap/long-press interactions
    /// to the appropriate `AppActionDispatcher` call or `AppRouter` navigation.
    private func handleNodeAction(_ action: NodeAction) {
        switch action {
        case .navigateRoot:
            router.navigate(to: .root, animated: true)
            currentScale = 1.0
        case .openSettings:
            _ = actionDispatcher.perform(.openSettings, source: .user)
        case .openProfile:
            _ = actionDispatcher.perform(.openProfile, source: .user)
        case .summonCoCaptain:
            _ = actionDispatcher.perform(.summonCoCaptain, source: .user)
        case .proSubscription:
            _ = actionDispatcher.perform(.proSubscription, source: .user)
        }
    }

    /// Returns `true` when the CoCaptain sheet should open at `.large` on iPhone
    /// to give onboarding steps enough vertical space for the chat interface.
    private var shouldOpenCoCaptainLargeForOnboarding: Bool {
        UIDevice.current.userInterfaceIdiom == .phone &&
            (onboarding.currentStep == .submitCoCaptainPrompt || onboarding.currentStep == .chatCoCaptain)
    }

    /// The set of allowed detents for the CoCaptain sheet.
    /// During onboarding steps that require full-height, `.medium` is temporarily
    /// removed to prevent the user from collapsing the sheet mid-flow.
    private var coCaptainAvailableDetents: Set<PresentationDetent> {
        coCaptainAllowsMediumDetent ? [.medium, .large] : [.large]
    }

    /// Configures detent and starting-size state before the CoCaptain sheet is presented.
    /// Locks out the `.medium` detent temporarily when onboarding requires a full-height panel;
    /// a `Task.yield` in the sheet's `onAppear` re-enables it once the open animation finishes.
    private func prepareCoCaptainPresentation() {
        let startsLarge = shouldOpenCoCaptainLargeForOnboarding
        coCaptainStartsLarge = startsLarge
        coCaptainAllowsMediumDetent = !startsLarge
        coCaptainDetent = startsLarge ? .large : .medium
    }

    /// Prepares presentation parameters, then presents the CoCaptain sheet.
    private func presentCoCaptain() {
        prepareCoCaptainPresentation()
        coCaptain.setPresented(true)
    }

    /// Checks if the user is currently on the onboarding step to submit a prompt, and if so,
    /// records the current response count baseline and hides the onboarding popover.
    private func beginInitialCoCaptainOnboardingWaitIfNeeded() {
        guard onboarding.currentStep == .submitCoCaptainPrompt else { return }
        onboardingInitialCoCaptainSuccessBaseline = coCaptain.successfulAssistantResponseCount
        onboarding.hidePopoverForCurrentStep()
    }

    /// Advances the onboarding flow from the prompt submission step once CoCaptain's successful
    /// response count exceeds the recorded baseline.
    private func advanceInitialCoCaptainOnboardingIfReady() {
        guard let baseline = onboardingInitialCoCaptainSuccessBaseline,
              onboarding.currentStep == .submitCoCaptainPrompt,
              coCaptain.successfulAssistantResponseCount > baseline else {
            return
        }

        onboardingInitialCoCaptainSuccessBaseline = nil
        onboarding.completeCurrentStep()
    }

    /// Registers every app-level action handler with `AppActionDispatcher`.
    ///
    /// Called once during `onAppear`. Handlers are closures that mutate view-local state
    /// (sheets, grid, viewport) or delegate to router/store methods. Arguments for
    /// parameterised actions (`.moveNode`, `.themeNode`, `.transformNode`) arrive as
    /// `[String: String]` dictionaries and are parsed defensively with early returns.
    private func configureActionDispatcher() {
        actionDispatcher.register(.goRoot) {
            router.goRoot()
            currentScale = 1.0
        }
        actionDispatcher.register(.goBack) {
            router.goBack()
        }
        actionDispatcher.register(.createNode) {
            router.activeStore.addNode(type: .miniApp)
        }
        actionDispatcher.register(.createFirebaseNode) {
            router.activeStore.addNode(type: .miniApp)
        }
        actionDispatcher.register(.summonCoCaptain) {
            coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
            presentCoCaptain()
        }
        actionDispatcher.register(.openFile) {
            showingFileImporter = true
        }
        actionDispatcher.register(.toggleGrid) {
            if gridOpacity > 0.0 {
                lastGridOpacity = gridOpacity
                gridOpacity = 0.0
            } else {
                gridOpacity = lastGridOpacity > 0.0 ? lastGridOpacity : 0.1
            }
        }
        actionDispatcher.register(.shareCanvas) {
            Task {
                if let url = await ExportService.export(from: router.activeStore, format: .webBundle(includeProjectContext: true)) {
                    exportURL = url
                    showExportSheet = true
                } else if let url = await ExportService.export(from: router.activeStore, format: .caocap) {
                    // Fallback to raw CAOCAP bundle
                    exportURL = url
                    showExportSheet = true
                }
            }
        }
        actionDispatcher.register(.proSubscription) {
            if coCaptain.isPresented {
                coCaptain.setPresented(false)
                Task {
                    try? await Task.sleep(for: .seconds(0.3))
                    showingPurchaseSheet = true
                }
            } else if showingProfile {
                showingProfile = false
                Task {
                    try? await Task.sleep(for: .seconds(0.3))
                    showingPurchaseSheet = true
                }
            } else if showingSettings {
                showingSettings = false
                Task {
                    try? await Task.sleep(for: .seconds(0.3))
                    showingPurchaseSheet = true
                }
            } else {
                showingPurchaseSheet = true
            }
        }
        actionDispatcher.register(.signIn) {
            showingSignIn = true
        }
        actionDispatcher.register(.openSettings) {
            showingSettings = true
        }
        actionDispatcher.register(.openProfile) {
            showingProfile = true
        }
        actionDispatcher.register(.openSnapshotBrowser) {
            showingSnapshotBrowser = true
        }
        actionDispatcher.register(.moveNode) { args in
            guard let args,
                  let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
                  let xStr = args["x"], let x = Double(xStr),
                  let yStr = args["y"], let y = Double(yStr) else { return }
            router.activeStore.updateNodePosition(id: uuid, position: CGPoint(x: x, y: y))
        }
        actionDispatcher.register(.themeNode) { args in
            guard let args,
                  let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
                  let themeStr = args["theme"], let theme = NodeTheme(rawValue: themeStr) else { return }
            router.activeStore.updateNodeTheme(id: uuid, theme: theme)
        }
        actionDispatcher.register(.transformNode) { args in
            guard let args,
                  let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
                  let typeStr = args["type"], let type = NodeType(rawValue: typeStr) else { return }
            router.activeStore.updateNodeType(id: uuid, type: type)
        }
        actionDispatcher.register(.organizeNodes) {
            router.activeStore.organizeNodes()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                viewport.fitTo(nodes: router.activeStore.nodes, containerSize: containerSize)
            }
        }
        actionDispatcher.register(.toggleHUD) {
            showingHUD.toggle()
        }
        actionDispatcher.register(.showActionsList) {
            commandPalette.setPresented(true, mode: .actionsList)
        }
        actionDispatcher.register(.createSubCanvas) {
            router.activeStore.addNode(type: .subCanvas)
        }
    }

    /// Wires the command palette's callbacks to the live router and action dispatcher.
    ///
    /// Must be called whenever the active workspace changes so the palette operates
    /// on the correct `ProjectStore`. Also computes the fly-to scale by preferring
    /// actual node frame data from `NodeFramePreferenceKey` before falling back to
    /// canonical default sizes.
    private func setupCommandHandlers() {
        syncCommandPaletteActions()
        commandPalette.nodes = router.activeStore.nodes
        commandPalette.onExecute = { actionID in
            _ = actionDispatcher.perform(actionID, source: .user)
        }
        commandPalette.onPinAction = { actionID in
            guard let definition = actionDispatcher.definition(for: actionID) else { return }
            router.activeStore.addShortcutNode(for: actionID, definition: definition)
            commandPalette.nodes = router.activeStore.nodes
        }
        commandPalette.onCreateNode = { type in
            router.activeStore.addNode(type: type)
            commandPalette.nodes = router.activeStore.nodes
        }
        commandPalette.onFlyToNode = { nodeId in
            guard let node = router.activeStore.nodes.first(where: { $0.id == nodeId }) else { return }
            
            var targetScale: CGFloat = 1.0
            if containerSize != .zero {
                let size: CGSize
                if let frameData = nodeFrames[nodeId] {
                    size = frameData.size
                } else {
                    switch node.type {
                    case .miniApp:
                        size = CGSize(width: 375, height: 667)
                    default:
                        size = CGSize(width: 280, height: 180)
                    }
                }
                let paddingFactor: CGFloat = 0.8
                let scaleX = (containerSize.width * paddingFactor) / size.width
                let scaleY = (containerSize.height * paddingFactor) / size.height
                targetScale = min(min(scaleX, scaleY), 1.2)
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                viewport.flyTo(nodePosition: node.position, containerSize: containerSize, targetScale: targetScale)
            }
        }
        commandPalette.onSubmitPrompt = { prompt in
            coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
            let purpose: CoCaptainTurnPurpose =
                onboarding.currentStep == .submitCoCaptainPrompt ? .onboardingWelcome : .standard
            beginInitialCoCaptainOnboardingWaitIfNeeded()
            presentCoCaptain()
            coCaptain.sendMessage(prompt, purpose: purpose)
            advanceInitialCoCaptainOnboardingIfReady()
        }
    }

    /// Imports a `.caocap` or `.json` project file chosen via the system file picker.
    ///
    /// Decoding and file-copy work runs on a detached `userInitiated` task to avoid
    /// blocking the main actor. The file is validated as a `ProjectSnapshot` before
    /// being written to the app's project directory. On success, navigates immediately
    /// to the imported project.
    private func handleFileImport(result: Result<[URL], Error>) {
        let logger = Logger(subsystem: "com.caocap.app", category: "FileImport")
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            
            guard selectedURL.startAccessingSecurityScopedResource() else {
                logger.error("Failed to start accessing security scoped resource.")
                return
            }
            
            Task {
                defer {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let newFileName = try await Task.detached(priority: .userInitiated) { () -> String in
                        let data = try Data(contentsOf: selectedURL)
                        let decoder = JSONDecoder()
                        
                        // Validate that the file is indeed a valid ProjectSnapshot
                        _ = try decoder.decode(ProjectSnapshot.self, from: data)
                        
                        // Copy or save it under a new project file name
                        let persistence = ProjectPersistenceService()
                        let newFileName = CanvasFileNaming.newCanvasFileName()
                        let targetURL = persistence.fileURL(for: newFileName)
                        
                        try data.write(to: targetURL, options: .atomic)
                        return newFileName
                    }.value
                    
                    logger.info("Successfully imported project to: \(newFileName)")
                    
                    // Navigate to the newly imported project
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        router.navigate(to: .project(newFileName))
                    }
                } catch {
                    logger.error("Import failed: \(error.localizedDescription)")
                }
            }
            
        case .failure(let error):
            logger.error("Document picker failed: \(error.localizedDescription)")
        }
    }

    /// Builds the list of actions shown in the command palette, filtering out
    /// context-irrelevant actions (e.g. "Go to Root" and "Go Back" when already at root).
    private func syncCommandPaletteActions() {
        let isProject: Bool
        if case .project = router.currentWorkspace {
            isProject = true
        } else {
            isProject = false
        }
        
        let isRoot = router.currentWorkspace == .root
        
        commandPalette.actions = actionDispatcher.availableActions.filter { action in
            // Don't show "Go to Root" when already on root
            if isRoot && action.id == .goRoot { return false }
            // Don't show "Go Back" when already on root (nothing to go back to)
            if isRoot && action.id == .goBack { return false }
            return true
        }
    }
}

#Preview {
    ContentView()
}
