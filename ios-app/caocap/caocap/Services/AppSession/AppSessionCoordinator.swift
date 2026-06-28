import Foundation
import Observation
import OSLog
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Orchestrates root-session state: routing, actions, palette binding, sheets, and onboarding hooks.
@MainActor
@Observable
final class AppSessionCoordinator {
    var router = AppRouter()
    var commandPalette = CommandPaletteViewModel()
    var coCaptain = CoCaptainViewModel()
    private(set) var actionDispatcher = AppActionDispatcher()

    var showingFileImporter = false
    var showingPurchaseSheet = false
    var showingSignIn = false
    var showingSettings = false
    var showingSnapshotBrowser = false
    var showingProfile = false
    var showingActivity = false
    var showingDaily = false
    var showConfetti = false

    var currentScale: CGFloat = 1.0
    var isLaunching = true
    var appUpdateService = AppUpdateService.shared
    var viewport = ViewportState()
    var nodeFrames: [UUID: NodeFrameData] = [:]
    var containerSize: CGSize = .zero

    var exportURL: URL?
    var showExportSheet = false

    var intro = IntroCoordinator()
    var personalization = PersonalizationOnboardingCoordinator()
    var onboarding = OnboardingCoordinator()

    var coCaptainDetent: PresentationDetent = .medium
    var coCaptainStartsLarge = false
    var coCaptainAllowsMediumDetent = true
    private var onboardingInitialCoCaptainSuccessBaseline: Int?

    private var actionsConfigured = false
    @ObservationIgnored private var activeUndoManager: UndoManager?

    private enum StorageKey {
        static let gridOpacity = "grid_opacity"
        static let lastGridOpacity = "last_grid_opacity"
        static let showingHUD = "showing_hud"
    }

    var gridOpacity: Double {
        get {
            if UserDefaults.standard.object(forKey: StorageKey.gridOpacity) == nil {
                return 0.1
            }
            return UserDefaults.standard.double(forKey: StorageKey.gridOpacity)
        }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.gridOpacity) }
    }

    private var lastGridOpacity: Double {
        get {
            if UserDefaults.standard.object(forKey: StorageKey.lastGridOpacity) == nil {
                return 0.1
            }
            return UserDefaults.standard.double(forKey: StorageKey.lastGridOpacity)
        }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.lastGridOpacity) }
    }

    var showingHUD: Bool {
        get { UserDefaults.standard.bool(forKey: StorageKey.showingHUD) }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.showingHUD) }
    }

    var coCaptainAvailableDetents: Set<PresentationDetent> {
        coCaptainAllowsMediumDetent ? [.medium, .large] : [.large]
    }

    // MARK: - Lifecycle

    func bootstrap(undoManager: UndoManager?) {
        activeUndoManager = undoManager
        bindCommandPalette()
        configureActionsIfNeeded()
        wireGamification()
        syncViewportWithActiveStore()
        attachUndoManager(undoManager)
        coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                self.isLaunching = false
            }
            if !self.intro.shouldPresent {
                self.startInteractiveOnboardingIfNeeded()
            }
        }
    }

    func handleWorkspaceChange(undoManager: UndoManager?) {
        activeUndoManager = undoManager
        bindCommandPalette()
        wireGamification()
        attachUndoManager(undoManager)
        coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
        syncCommandPaletteActions()
        commandPalette.nodes = router.activeStore.nodes
        syncViewportWithActiveStore()
    }

    func updateContainerSize(_ size: CGSize) {
        containerSize = size
    }

    /// Called when the motivational intro tour finishes. Presents personalization if needed.
    func finishIntroFlow() {
        startInteractiveOnboardingIfNeeded()
    }

    /// Called when the personalization survey finishes or is skipped.
    func finishPersonalizationFlow() {
        onboarding.startIfNeeded()
    }

    /// Starts the gesture tutorial only when intro and personalization are both complete.
    func startInteractiveOnboardingIfNeeded() {
        guard !personalization.shouldPresent else { return }
        onboarding.startIfNeeded()
    }

    func restartOnboarding() {
        restoreTutorialPortalIfNeeded()
        intro.reset()
        personalization.reset()
        onboarding.reset()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
    }

    func restartTutorial() {
        restoreTutorialPortalIfNeeded()
        onboarding.reset()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
        onboarding.startIfNeeded()
    }

    private func restoreTutorialPortalIfNeeded() {
        guard let tutorial = RootCanvasProvider.nodes.first(where: {
            $0.id == RootCanvasProvider.tutorialNodeID
        }) else { return }
        router.rootStore.ensureNodeExists(tutorial)
    }

    func eraseEverything(authManager: AuthenticationManager) async throws {
        guard !LocalMLXModelManager.shared.isDownloadingLocalModel else {
            throw AppDataResetError.localModelDownloadInProgress
        }

        coCaptain.stopStreaming()
        onboarding.reset()

        let stores = [router.rootStore] + Array(router.projects.values)
        for store in stores {
            await store.prepareForDataReset()
        }

        authManager.signOut()
        LocalMLXModelManager.shared.updateHFToken("")
        LocalMLXModelManager.shared.clearLocalModelCache()
        try await AppDataResetService.eraseLocalData()
        ActivityStore.shared.reset()
        GamificationStore.shared.reset()

        router = AppRouter()
        wireGamification()
        commandPalette = CommandPaletteViewModel()
        coCaptain = CoCaptainViewModel()
        actionDispatcher = AppActionDispatcher()
        intro = IntroCoordinator()
        personalization = PersonalizationOnboardingCoordinator()
        onboarding = OnboardingCoordinator()
        viewport = ViewportState()
        currentScale = 1
        nodeFrames = [:]
        onboardingInitialCoCaptainSuccessBaseline = nil
        actionsConfigured = false

        bindCommandPalette()
        configureActionsIfNeeded()
        attachUndoManager(activeUndoManager)
        coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
        syncViewportWithActiveStore()
        isLaunching = false
    }

    func updateNodeFrames(_ frames: [UUID: NodeFrameData]) {
        nodeFrames = frames
    }

    // MARK: - Undo

    func performUndo(undoManager: UndoManager?) {
        undoManager?.undo()
        router.activeStore.undoStackChanged += 1
    }

    func performRedo(undoManager: UndoManager?) {
        undoManager?.redo()
        router.activeStore.undoStackChanged += 1
    }

    func handleUndoStackChanged() {
        router.activeStore.undoStackChanged += 1
    }

    // MARK: - Node Actions

    func handleNodeAction(_ action: NodeAction) {
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
        case .openActivity:
            showingActivity = true
        case .openDaily:
            showingDaily = true
        case .openWhatsApp:
            if let url = SupportContact.whatsAppURL {
                UIApplication.shared.open(url)
            }
        }
    }

    func handleSubCanvasNavigation(fileName: String) {
        router.navigateToSubCanvas(fileName: fileName)
        if fileName == RootCanvasProvider.tutorialFileName,
           onboarding.currentStep == .openTutorial {
            onboarding.completeCurrentStep()
        }
    }

    // MARK: - Onboarding + CoCaptain Presentation

    func handleCommandPalettePresentationChange(isPresented: Bool) {
        if isPresented {
            commandPalette.nodes = router.activeStore.nodes
            if onboarding.currentStep == .tapFAB {
                onboarding.completeCurrentStep()
            }
        } else if onboarding.currentStep == .typeCoCaptainPrompt || onboarding.currentStep == .submitCoCaptainPrompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if (self.onboarding.currentStep == .typeCoCaptainPrompt || self.onboarding.currentStep == .submitCoCaptainPrompt),
                   !self.coCaptain.isPresented {
                    self.onboarding.moveToStep(.tapFAB)
                }
            }
        }
    }

    func handleCoCaptainPresentationChange(isPresented: Bool) {
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

    func handleCoCaptainSuccessCountChange() {
        advanceInitialCoCaptainOnboardingIfReady()
    }

    func handleCoCaptainSheetAppeared() {
        guard coCaptainStartsLarge else { return }
        Task { @MainActor in
            await Task.yield()
            self.coCaptainAllowsMediumDetent = true
        }
    }

    // MARK: - File Import

    func importProject(from result: Result<[URL], Error>) {
        let logger = Logger(subsystem: "com.caocap.app", category: "FileImport")
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }

            guard selectedURL.startAccessingSecurityScopedResource() else {
                logger.error("Failed to start accessing security scoped resource.")
                return
            }

            Task { @MainActor [weak self] in
                defer {
                    selectedURL.stopAccessingSecurityScopedResource()
                }

                do {
                    let newFileName = try await Task.detached(priority: .userInitiated) { () -> String in
                        let data = try Data(contentsOf: selectedURL)
                        let decoder = JSONDecoder()
                        _ = try decoder.decode(ProjectSnapshot.self, from: data)

                        let persistence = ProjectPersistenceService()
                        let newFileName = CanvasFileNaming.newCanvasFileName()
                        let targetURL = persistence.fileURL(for: newFileName)
                        try data.write(to: targetURL, options: .atomic)
                        return newFileName
                    }.value

                    logger.info("Successfully imported project to: \(newFileName)")
                    ActivityStore.shared.recordSuccessfulSave(at: Date())

                    guard let self else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.router.navigate(to: .project(newFileName))
                    }
                } catch {
                    logger.error("Import failed: \(error.localizedDescription)")
                }
            }

        case .failure(let error):
            logger.error("Document picker failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Command Palette

    func bindCommandPalette() {
        syncCommandPaletteActions()
        commandPalette.nodes = router.activeStore.nodes
        commandPalette.onExecute = { [weak self] actionID in
            guard let self else { return }
            _ = self.actionDispatcher.perform(actionID, source: .user)
        }
        commandPalette.onPinAction = { [weak self] actionID in
            guard let self,
                  let definition = self.actionDispatcher.definition(for: actionID) else { return }
            self.router.activeStore.addShortcutNode(for: actionID, definition: definition)
            self.commandPalette.nodes = self.router.activeStore.nodes
        }
        commandPalette.onCreateNode = { [weak self] type in
            guard let self else { return }
            self.router.activeStore.addNode(type: type)
            self.commandPalette.nodes = self.router.activeStore.nodes
        }
        commandPalette.onFlyToNode = { [weak self] nodeId in
            self?.flyToNode(nodeId)
        }
        commandPalette.onSubmitPrompt = { [weak self] prompt in
            self?.submitCoCaptainPrompt(prompt)
        }
    }

    func syncCommandPaletteActions() {
        let isRoot = router.currentWorkspace == .root
        commandPalette.actions = actionDispatcher.availableActions.filter { action in
            if isRoot && action.id == .goRoot { return false }
            if isRoot && action.id == .goBack { return false }
            return true
        }
    }

    func filteredPaletteActionIDs(at workspace: WorkspaceState) -> [AppActionID] {
        let isRoot = workspace == .root
        return actionDispatcher.availableActions.compactMap { action in
            if isRoot && action.id == .goRoot { return nil }
            if isRoot && action.id == .goBack { return nil }
            return action.id
        }
    }

    func flyToTargetScale(for node: SpatialNode, nodeId: UUID) -> CGFloat {
        guard containerSize != .zero else { return 1.0 }

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
        return min(min(scaleX, scaleY), 1.2)
    }

    // MARK: - Private

    private func attachUndoManager(_ undoManager: UndoManager?) {
        router.activeStore.undoManager = undoManager
        router.rootStore.undoManager = undoManager
    }

    private func syncViewportWithActiveStore() {
        viewport = ViewportState(
            offset: router.activeStore.viewportOffset,
            scale: router.activeStore.viewportScale
        )
        currentScale = viewport.scale
    }

    private func wireGamification() {
        let handler: ([DailyChallengeDefinition]) -> Void = { [weak self] _ in
            self?.celebrateChallengeCompletion()
        }
        router.rootStore.onChallengesCompleted = handler
        for store in router.projects.values {
            store.onChallengesCompleted = handler
        }
        router.activeStore.onChallengesCompleted = handler
        _ = GamificationStore.shared.evaluateMiniApps(
            htmlSamples: router.activeStore.nodes.compactMap(\.miniApp?.compiledHTML)
        )
    }

    private func celebrateChallengeCompletion() {
        HapticsManager.shared.notification(.success)
        showConfetti = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.showConfetti = false
        }
    }

    func ensureActionsConfigured() {
        configureActionsIfNeeded()
    }

    private func configureActionsIfNeeded() {
        guard !actionsConfigured else { return }
        actionsConfigured = true
        configureActions()
    }

    private func configureActions() {
        actionDispatcher.register(.goRoot) { [weak self] in
            guard let self else { return }
            self.router.goRoot()
            self.currentScale = 1.0
        }
        actionDispatcher.register(.goBack) { [weak self] in
            self?.router.goBack()
        }
        actionDispatcher.register(.createNode) { [weak self] in
            self?.router.activeStore.addNode(type: .miniApp)
        }
        actionDispatcher.register(.createFirebaseNode) { [weak self] in
            self?.router.activeStore.addNode(type: .miniApp)
        }
        actionDispatcher.register(.summonCoCaptain) { [weak self] in
            guard let self else { return }
            self.coCaptain.configureProjectSession(store: self.router.activeStore, dispatcher: self.actionDispatcher)
            self.presentCoCaptain()
        }
        actionDispatcher.register(.openFile) { [weak self] in
            self?.showingFileImporter = true
        }
        actionDispatcher.register(.toggleGrid) { [weak self] in
            self?.toggleGrid()
        }
        actionDispatcher.register(.shareCanvas) { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let url = await ExportService.export(from: self.router.activeStore, format: .webBundle(includeProjectContext: true)) {
                    self.exportURL = url
                    self.showExportSheet = true
                } else if let url = await ExportService.export(from: self.router.activeStore, format: .caocap) {
                    self.exportURL = url
                    self.showExportSheet = true
                }
            }
        }
        actionDispatcher.register(.proSubscription) { [weak self] in
            self?.presentPurchaseSheet()
        }
        actionDispatcher.register(.signIn) { [weak self] in
            self?.showingSignIn = true
        }
        actionDispatcher.register(.openSettings) { [weak self] in
            self?.showingSettings = true
        }
        actionDispatcher.register(.openProfile) { [weak self] in
            self?.showingProfile = true
        }
        actionDispatcher.register(.openSnapshotBrowser) { [weak self] in
            self?.showingSnapshotBrowser = true
        }
        actionDispatcher.register(.moveNode) { [weak self] args in
            self?.moveNode(arguments: args)
        }
        actionDispatcher.register(.themeNode) { [weak self] args in
            self?.themeNode(arguments: args)
        }
        actionDispatcher.register(.transformNode) { [weak self] args in
            self?.transformNode(arguments: args)
        }
        actionDispatcher.register(.organizeNodes) { [weak self] in
            guard let self else { return }
            self.router.activeStore.organizeNodes()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                self.viewport.fitTo(nodes: self.router.activeStore.nodes, containerSize: self.containerSize)
            }
        }
        actionDispatcher.register(.toggleHUD) { [weak self] in
            guard let self else { return }
            self.showingHUD.toggle()
        }
        actionDispatcher.register(.showActionsList) { [weak self] in
            self?.commandPalette.setPresented(true, mode: .actionsList)
        }
        actionDispatcher.register(.createSubCanvas) { [weak self] in
            self?.router.activeStore.addNode(type: .subCanvas)
        }
    }

    private func toggleGrid() {
        if gridOpacity > 0.0 {
            lastGridOpacity = gridOpacity
            gridOpacity = 0.0
        } else {
            gridOpacity = lastGridOpacity > 0.0 ? lastGridOpacity : 0.1
        }
    }

    private func presentPurchaseSheet() {
        if coCaptain.isPresented {
            coCaptain.setPresented(false)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.3))
                self?.showingPurchaseSheet = true
            }
        } else if showingProfile {
            showingProfile = false
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.3))
                self?.showingPurchaseSheet = true
            }
        } else if showingSettings {
            showingSettings = false
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.3))
                self?.showingPurchaseSheet = true
            }
        } else {
            showingPurchaseSheet = true
        }
    }

    private func moveNode(arguments args: [String: String]?) {
        guard let args,
              let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
              let xStr = args["x"], let x = Double(xStr),
              let yStr = args["y"], let y = Double(yStr) else { return }
        router.activeStore.updateNodePosition(id: uuid, position: CGPoint(x: x, y: y))
    }

    private func themeNode(arguments args: [String: String]?) {
        guard let args,
              let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
              let themeStr = args["theme"], let theme = NodeTheme(rawValue: themeStr) else { return }
        router.activeStore.updateNodeTheme(id: uuid, theme: theme)
    }

    private func transformNode(arguments args: [String: String]?) {
        guard let args,
              let idString = args["nodeId"], let uuid = UUID(uuidString: idString),
              let typeStr = args["type"], let type = NodeType(rawValue: typeStr) else { return }
        router.activeStore.updateNodeType(id: uuid, type: type)
    }

    private func flyToNode(_ nodeId: UUID) {
        guard let node = router.activeStore.nodes.first(where: { $0.id == nodeId }) else { return }
        let targetScale = flyToTargetScale(for: node, nodeId: nodeId)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            viewport.flyTo(nodePosition: node.position, containerSize: containerSize, targetScale: targetScale)
        }
    }

    private func submitCoCaptainPrompt(_ prompt: String) {
        coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
        let purpose: CoCaptainTurnPurpose =
            onboarding.currentStep == .submitCoCaptainPrompt ? .onboardingWelcome : .standard
        beginInitialCoCaptainOnboardingWaitIfNeeded()
        presentCoCaptain()
        coCaptain.sendMessage(prompt, purpose: purpose)
        advanceInitialCoCaptainOnboardingIfReady()
    }

    private var shouldOpenCoCaptainLargeForOnboarding: Bool {
        UIDevice.current.userInterfaceIdiom == .phone &&
            (onboarding.currentStep == .submitCoCaptainPrompt || onboarding.currentStep == .chatCoCaptain)
    }

    private func prepareCoCaptainPresentation() {
        let startsLarge = shouldOpenCoCaptainLargeForOnboarding
        coCaptainStartsLarge = startsLarge
        coCaptainAllowsMediumDetent = !startsLarge
        coCaptainDetent = startsLarge ? .large : .medium
    }

    private func presentCoCaptain() {
        prepareCoCaptainPresentation()
        coCaptain.setPresented(true)
    }

    private func beginInitialCoCaptainOnboardingWaitIfNeeded() {
        guard onboarding.currentStep == .submitCoCaptainPrompt else { return }
        onboardingInitialCoCaptainSuccessBaseline = coCaptain.successfulAssistantResponseCount
        onboarding.hidePopoverForCurrentStep()
    }

    private func advanceInitialCoCaptainOnboardingIfReady() {
        guard let baseline = onboardingInitialCoCaptainSuccessBaseline,
              onboarding.currentStep == .submitCoCaptainPrompt,
              coCaptain.successfulAssistantResponseCount > baseline else {
            return
        }

        onboardingInitialCoCaptainSuccessBaseline = nil
        onboarding.completeCurrentStep()
    }
}
