import SwiftUI
import UniformTypeIdentifiers
import OSLog

extension Notification.Name {
    static let openCommandPalette = Notification.Name("openCommandPalette")
    static let summonCoCaptain = Notification.Name("summonCoCaptain")
    static let performUndo = Notification.Name("performUndo")
    static let performRedo = Notification.Name("performRedo")
}

struct ContentView: View {
    @State var commandPalette = CommandPaletteViewModel()
    @State var coCaptain = CoCaptainViewModel()
    @State private var actionDispatcher = AppActionDispatcher()
    @State private var router = AppRouter()
    @AppStorage("grid_opacity") private var gridOpacity: Double = 0.1
    @AppStorage("last_grid_opacity") private var lastGridOpacity: Double = 0.1
    @AppStorage("showing_hud") private var showingHUD: Bool = false
    @State private var showingFileImporter = false
    @State private var showingPurchaseSheet = false
    @State private var showingSignIn = false
    @State private var showingSettings = false
    @State private var showingSnapshotBrowser = false
    @State private var showingProfile = false
    @State private var showingProjectExplorer = false
    @State private var currentScale: CGFloat = 1.0
    @Environment(\.undoManager) var undoManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTheme = "System"
    @State private var isLaunching = true
    @State private var appUpdateService = AppUpdateService.shared
    @State private var viewport = ViewportState()
    @State private var showingNodeCreationMenu = false
    @State private var nodeFrames: [UUID: NodeFrameData] = [:]
    @State private var containerSize: CGSize = .zero
    
    // Export State
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showExportSheet = false
    
    // Onboarding
    @State private var onboarding = OnboardingCoordinator()

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
                    }
                )
                .id("project_canvas_\(fileName)")
            }

            if showingHUD {
                CanvasHUDView(
                    store: router.activeStore,
                    viewportScale: currentScale,
                    onSignInTapped: { showingSignIn = true },
                    onProjectExplorerTapped: { showingProjectExplorer = true },
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
        .background(Color.black.ignoresSafeArea())
        .overlay {
            if isLaunching {
                LaunchScreenView()
                    .transition(.opacity)
                    .zIndex(100)
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
        .sheet(isPresented: $showingNodeCreationMenu) {
            NodeCreationMenuView { type in
                router.activeStore.addNode(type: type)
                showingNodeCreationMenu = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $coCaptain.isPresented) {
            CoCaptainView(viewModel: coCaptain)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground {
                    Color.white.opacity(0.4)
                        .background(.ultraThinMaterial)
                }
                .presentationBackgroundInteraction(.enabled)
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
        .sheet(isPresented: $showingProjectExplorer) {
            ProjectExplorerView(onSelect: { fileName in
                router.navigate(to: .project(fileName))
            })
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
                // Start onboarding after launch screen fades
                onboarding.startIfNeeded()
            }
        }
        .task {
            await appUpdateService.checkForUpdate()
        }
        .onChange(of: commandPalette.isPresented) { _, isPresented in
            if isPresented {
                if onboarding.currentStep == .tapFAB {
                    onboarding.completeCurrentStep()
                }
            } else {
                if onboarding.currentStep == .searchBarCoCaptain {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if onboarding.currentStep == .searchBarCoCaptain && !coCaptain.isPresented {
                            onboarding.moveToStep(.tapFAB)
                        }
                    }
                }
            }
        }
        .onChange(of: coCaptain.isPresented) { _, isPresented in
            if isPresented {
                if onboarding.currentStep == .searchBarCoCaptain {
                    onboarding.completeCurrentStep()
                } else if onboarding.currentStep == .tapFAB {
                    onboarding.moveToStep(.chatCoCaptain)
                }
            } else {
                if onboarding.currentStep == .dismissCoCaptain {
                    onboarding.completeCurrentStep()
                } else if onboarding.currentStep == .chatCoCaptain {
                    onboarding.moveToStep(.tapFAB)
                }
            }
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
            showOnboardingPopover: Binding(
                get: {
                    guard let step = onboarding.currentStep else { return false }
                    return onboarding.showPopover && (step == .tapFAB || step == .longPressFAB)
                },
                set: { newValue in
                    onboarding.showPopover = newValue
                }
            ),
            onboardingPopoverContent: { offset in
                if let step = onboarding.currentStep, (step == .tapFAB || step == .longPressFAB) {
                    return AnyView(
                        OnboardingPopoverCard(step: step, arrowOffset: offset) {
                            onboarding.skip()
                        }
                    )
                }
                return AnyView(EmptyView())
            }
        )
    }
    
    private var currentColorScheme: ColorScheme? {
        switch selectedTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    private func handleNodeAction(_ action: NodeAction) {
        switch action {
        case .navigateRoot:
            router.navigate(to: .root, animated: true)
            currentScale = 1.0
        case .createNewProject:
            router.createNewProject()
        case .openSettings:
            _ = actionDispatcher.perform(.openSettings, source: .user)
        case .openProfile:
            _ = actionDispatcher.perform(.openProfile, source: .user)
        case .openProjectExplorer:
            _ = actionDispatcher.perform(.openProjectExplorer, source: .user)
        case .resumeLastProject:
            router.resumeLastProject()
        case .summonCoCaptain:
            _ = actionDispatcher.perform(.summonCoCaptain, source: .user)
        case .proSubscription:
            _ = actionDispatcher.perform(.proSubscription, source: .user)
        }
    }

    private func configureActionDispatcher() {
        actionDispatcher.configure(
            goRoot: {
                router.goRoot()
                currentScale = 1.0
            },
            goBack: {
                router.goBack()
            },
            newProject: {
                router.createNewProject()
            },
            createNode: {
                showingNodeCreationMenu = true
            },
            onCreateTextNode: {
                router.activeStore.addNode(type: .text)
            },
            onCreateCalculationNode: {
                router.activeStore.addNode(type: .calculation)
            },
            onCreateDisplayNode: {
                router.activeStore.addNode(type: .display)
            },
            onCreateNumberNode: {
                router.activeStore.addNode(type: .number)
            },
            onCreateTableNode: {
                router.activeStore.addNode(type: .table)
            },
            onCreateChartNode: {
                router.activeStore.addNode(type: .chart)
            },
            onCreateFirebaseNode: {
                router.activeStore.addNode(type: .firebase)
            },
            onCreateAiAgentNode: {
                router.activeStore.addNode(type: .aiAgent)
            },
            summonCoCaptain: {
                coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
                coCaptain.setPresented(true)
            },
            openFile: {
                showingFileImporter = true
            },
            toggleGrid: {
                if gridOpacity > 0.0 {
                    lastGridOpacity = gridOpacity
                    gridOpacity = 0.0
                } else {
                    gridOpacity = lastGridOpacity > 0.0 ? lastGridOpacity : 0.1
                }
            },
            shareProject: {
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
            },
            proSubscription: {
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
            },
            signIn: {
                showingSignIn = true
            },
            openSettings: {
                showingSettings = true
            },
            openProfile: {
                showingProfile = true
            },
            openProjectExplorer: {
                showingProjectExplorer = true
            },
            openSnapshotBrowser: {
                showingSnapshotBrowser = true
            },
            moveNode: { args in
                guard let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
                      let xStr = args["x"], let x = Double(xStr),
                      let yStr = args["y"], let y = Double(yStr) else { return }
                router.activeStore.updateNodePosition(id: uuid, position: CGPoint(x: x, y: y))
            },
            themeNode: { args in
                guard let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
                      let themeStr = args["theme"], let theme = NodeTheme(rawValue: themeStr) else { return }
                router.activeStore.updateNodeTheme(id: uuid, theme: theme)
            },
            transformNode: { args in
                guard let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
                      let typeStr = args["type"], let type = NodeType(rawValue: typeStr) else { return }
                router.activeStore.updateNodeType(id: uuid, type: type)
            },
            organizeNodes: {
                router.activeStore.organizeNodes()
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    viewport.fitTo(nodes: router.activeStore.nodes, containerSize: containerSize)
                }
            },
            toggleHUD: {
                showingHUD.toggle()
            },
            showActionsList: {
                commandPalette.setPresented(true, mode: .actionsList)
            },
            createSubCanvas: {
                router.activeStore.addNode(type: .subCanvas)
            }
        )
    }

    private func setupCommandHandlers() {
        syncCommandPaletteActions()
        commandPalette.nodes = router.activeStore.nodes
        commandPalette.onExecute = { actionID in
            _ = actionDispatcher.perform(actionID, source: .user)
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
                    case .webView:
                        size = CGSize(width: 375, height: 667)
                    case .console:
                        size = CGSize(width: 360, height: 300)
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
            coCaptain.setPresented(true)
            coCaptain.sendMessage(prompt)
        }
    }

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
                        let newFileName = "project_\(UUID().uuidString).json"
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
