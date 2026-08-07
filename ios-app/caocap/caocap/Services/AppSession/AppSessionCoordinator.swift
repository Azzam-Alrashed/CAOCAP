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
    var showingMiniAppLimitAlert = false
    var showingUsage = false
    var showingSignIn = false
    var showingSettings = false
    var showingSnapshotBrowser = false
    var showingProfile = false
    var showingActivity = false
    var showingDaily = false
    var showingHelp = false
    var showingAppIconPicker = false
    var showConfetti = false
    var showingCopilotCall = false
    var showingCopilotPicker = false
    var activeCopilotCallMode: CopilotInteractionMode = .voice
    var selectedCopilot: CopilotPersona = UserProfileStore().loadSelectedCopilot()
    @ObservationIgnored var copilotCallViewModel: CopilotCallViewModel?

    var currentScale: CGFloat = 1.0
    var isLaunching = true
    var appUpdateService = AppUpdateService.shared
    var viewport = ViewportState()
    var nodeSizes: [UUID: CGSize] = [:]
    var containerSize: CGSize = .zero
    /// Briefly highlights a node after fly-to navigation from CoCaptain or the command palette.
    var canvasFocusNodeID: UUID?
    @ObservationIgnored private var canvasFocusClearTask: Task<Void, Never>?
    /// Matches `LaunchScreenView` entrance length so the brand animation can land.
    /// Tests may shorten this to avoid sleeping for the full brand dwell.
    var launchMinimumVisibleDuration: Duration = .milliseconds(1_200)
    /// Hard cap so splash never blocks interaction longer than the old fixed delay.
    var launchMaximumVisibleDuration: Duration = .seconds(2.5)
    @ObservationIgnored private var launchDismissTask: Task<Void, Never>?

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
    

    init() {
        onboarding.onLessonWillStart = { [weak self] lessonID in
            self?.prepareWorkspace(for: lessonID)
        }
        onboarding.onTutorialCompleted = { [weak self] in
            self?.celebrateTutorialGraduation()
        }
    }

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
        selectedCopilot = UserProfileStore().loadSelectedCopilot()
        bindCommandPalette()
        configureActionsIfNeeded()
        actionDispatcher.refreshCopilotActionTitle()
        wireGamification()
        syncViewportWithActiveStore()
        attachUndoManager(undoManager)
        coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)

        scheduleLaunchOverlayDismissal()
    }

    /// Dismisses the launch overlay when the session is ready, after a short brand
    /// minimum and before a hard maximum — not a fixed cosmetic sleep.
    private func scheduleLaunchOverlayDismissal() {
        launchDismissTask?.cancel()
        launchDismissTask = Task { @MainActor [weak self] in
            await self?.dismissLaunchOverlayWhenReady()
        }
    }

    private func dismissLaunchOverlayWhenReady() async {
        let clock = ContinuousClock()
        let started = clock.now

        await waitForLaunchReadiness()
        guard !Task.isCancelled else { return }

        let readyAt = clock.now
        let minAt = started + launchMinimumVisibleDuration
        let maxAt = started + launchMaximumVisibleDuration
        let dismissAt = min(max(readyAt, minAt), maxAt)
        let remaining = dismissAt - clock.now
        if remaining > .zero {
            try? await Task.sleep(for: remaining)
        }
        guard !Task.isCancelled else { return }

        finishLaunchOverlayDismissal()
    }

    /// Root `ProjectStore` loads synchronously in `AppRouter` before UI appears.
    /// Yield so SwiftUI can commit the first canvas frame under the overlay.
    private func waitForLaunchReadiness() async {
        await Task.yield()
    }

    private func finishLaunchOverlayDismissal() {
        guard isLaunching else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            isLaunching = false
        }
        PerformanceSignposts.endLaunch()
        if !intro.shouldPresent {
            startInteractiveOnboardingIfNeeded()
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
        selectedCopilot = UserProfileStore().loadSelectedCopilot()
        actionDispatcher.refreshCopilotActionTitle()
        onboarding.startIfNeeded()
    }

    func updateSelectedCopilot(_ persona: CopilotPersona) {
        UserProfileStore().saveSelectedCopilot(persona)
        selectedCopilot = persona
        actionDispatcher.refreshCopilotActionTitle()
    }

    /// Re-opens the intro tour while personalization remains in progress.
    func returnToIntroFromPersonalization() {
        intro.reset()
    }

    /// Starts the gesture tutorial only when intro and personalization are both complete.
    func startInteractiveOnboardingIfNeeded() {
        guard !personalization.shouldPresent else { return }
        onboarding.startIfNeeded()
    }

    func restartPersonalization() {
        personalization.reset()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
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

    func openTutorialFromHelp() {
        showingHelp = false
        handleSubCanvasNavigation(fileName: RootCanvasProvider.tutorialFileName)
    }

    func restartTutorialFromHelp() {
        showingHelp = false
        restartTutorial()
    }

    func startLessonFromHelp(_ lessonID: OnboardingLessonID) {
        showingHelp = false
        restoreTutorialPortalIfNeeded()
        prepareWorkspace(for: lessonID)
        onboarding.startLesson(lessonID, advancesThroughLessons: false)
    }

    func prepareWorkspace(for lessonID: OnboardingLessonID) {
        if OnboardingLessonsManifest.optionalLessonIDs.contains(lessonID) {
            prepareTutorialLessonWorkspace()
            return
        }

        switch lessonID {
        case .canvasBasics:
            router.navigate(to: .root, addToStack: false, animated: false)
            syncViewportWithActiveStore()
        case .omniboxNavigation:
            prepareOmniboxNavigationWorkspace()
        case .miniAppPreview:
            prepareHelpDiscoveryLessonWorkspace()
        case .coCaptainChat, .moveAndOrganize:
            // Exhaustiveness fallback; optional lessons are handled above.
            prepareTutorialLessonWorkspace()
        }
    }

    private func prepareOmniboxNavigationWorkspace() {
        commandPalette.setPresented(false)
        coCaptain.setPresented(false)
        restoreTutorialPortalIfNeeded()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
        commandPalette.nodes = router.activeStore.nodes
    }

    private func prepareCoCaptainLessonWorkspace() {
        prepareTutorialLessonWorkspace()
        coCaptain.configureNodeSession(
            store: router.activeStore,
            nodeID: TutorialCanvasProvider.miniAppNodeID,
            dispatcher: actionDispatcher
        )
        presentCoCaptain()
    }

    private func prepareHelpDiscoveryLessonWorkspace() {
        commandPalette.setPresented(false)
        coCaptain.setPresented(false)
        restoreTutorialPortalIfNeeded()
        router.navigate(to: .root, addToStack: false, animated: false)
        syncViewportWithActiveStore()
        commandPalette.nodes = router.activeStore.nodes
    }

    private func celebrateTutorialGraduation() {
        HapticsManager.shared.notification(.success)
        showConfetti = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.showConfetti = false
        }
    }

    func openDemoCanvasFromHelp(fileName: String) {
        showingHelp = false
        handleSubCanvasNavigation(fileName: fileName)
    }

    private func restoreTutorialPortalIfNeeded() {
        guard let tutorial = RootCanvasProvider.nodes.first(where: {
            $0.id == RootCanvasProvider.tutorialNodeID
        }) else { return }
        router.rootStore.ensureNodeExists(tutorial)
    }

    private func prepareTutorialLessonWorkspace() {
        commandPalette.setPresented(false)
        coCaptain.setPresented(false)
        restoreTutorialPortalIfNeeded()
        router.navigateToSubCanvas(fileName: RootCanvasProvider.tutorialFileName)
        router.activeStore.ensureNodeExists(TutorialCanvasProvider.practiceMiniAppNode)
        syncViewportWithActiveStore()
        commandPalette.nodes = router.activeStore.nodes
    }

    func eraseEverything(authManager: AuthenticationManager) async throws {
        guard !LocalGemmaModelManager.shared.isDownloadingLocalModel else {
            throw AppDataResetError.localModelDownloadInProgress
        }

        coCaptain.stopStreaming()
        onboarding.reset()

        let stores = [router.rootStore] + Array(router.projects.values)
        for store in stores {
            await store.prepareForDataReset()
        }

        authManager.signOut()
        LocalGemmaModelManager.shared.clearLocalModelCache()
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
        onboarding.onLessonWillStart = { [weak self] lessonID in
            self?.prepareWorkspace(for: lessonID)
        }
        onboarding.onTutorialCompleted = { [weak self] in
            self?.celebrateTutorialGraduation()
        }
        viewport = ViewportState()
        currentScale = 1
        nodeSizes = [:]
        onboardingInitialCoCaptainSuccessBaseline = nil
        actionsConfigured = false

        bindCommandPalette()
        configureActionsIfNeeded()
        attachUndoManager(activeUndoManager)
        coCaptain.configureProjectSession(store: router.activeStore, dispatcher: actionDispatcher)
        syncViewportWithActiveStore()
        launchDismissTask?.cancel()
        launchDismissTask = nil
        isLaunching = false
        PerformanceSignposts.endLaunch()
    }

    func updateNodeSizes(_ sizes: [UUID: CGSize]) {
        nodeSizes = sizes
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
        guard let actionID = action.appActionID else { return }
        _ = actionDispatcher.perform(actionID, source: .user)
    }

    func handleSubCanvasNavigation(fileName: String) {
        router.navigateToSubCanvas(fileName: fileName)
        if fileName == RootCanvasProvider.tutorialFileName {
            if onboarding.currentStep == .openTutorial {
                onboarding.completeCurrentStep()
            }
            return
        }

        if onboarding.currentStep == .openPortal &&
            (fileName == RootCanvasProvider.pacManFileName || fileName == RootCanvasProvider.xoFileName) {
            onboarding.completeCurrentStep()
            if onboarding.currentStep == .chatCoCaptainGameEdit {
                presentCoCaptain()
            }
        }
    }

    // MARK: - Onboarding + CoCaptain Presentation

    func handleCommandPalettePresentationChange(isPresented: Bool) {
        if isPresented {
            commandPalette.nodes = router.activeStore.nodes
            if onboarding.currentStep == .tapFAB || onboarding.currentStep == .returnToRoot
                || onboarding.currentStep == .runOrganizeNodes {
                onboarding.completeCurrentStep()
            }
        } else if onboarding.currentStep == .typeCoCaptainPrompt
                    || onboarding.currentStep == .submitCoCaptainPrompt
                    || onboarding.currentStep == .typeGoBackInOmnibox
                    || onboarding.currentStep == .tapGoBackAction
                    || onboarding.currentStep == .openHelpCenter {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if (self.onboarding.currentStep == .typeCoCaptainPrompt || self.onboarding.currentStep == .submitCoCaptainPrompt),
                   !self.coCaptain.isPresented {
                    self.onboarding.moveToStep(.typeCoCaptainPrompt)
                } else if (self.onboarding.currentStep == .typeGoBackInOmnibox
                            || self.onboarding.currentStep == .tapGoBackAction),
                          !self.commandPalette.isPresented {
                    if self.onboarding.activeLessonID == .canvasBasics {
                        self.onboarding.moveToStep(.tapGoBackAction)
                    } else {
                        self.onboarding.moveToStep(.returnToRoot)
                    }
                } else if self.onboarding.currentStep == .openHelpCenter,
                          !self.showingHelp {
                    self.onboarding.moveToStep(.tapFAB)
                }
            }
        }
    }

    func handleCoCaptainPresentationChange(isPresented: Bool) {
        if isPresented {
            Task {
                await SubscriptionManager.shared.refreshEntitlements()
            }
            if onboarding.currentStep == .submitCoCaptainPrompt {
                onboarding.hidePopoverForCurrentStep()
            }
        } else {
            onboardingInitialCoCaptainSuccessBaseline = nil
            if onboarding.currentStep == .dismissCoCaptain {
                onboarding.completeCurrentStep()
            } else if onboarding.currentStep == .submitCoCaptainPrompt {
                onboarding.moveToStep(.typeCoCaptainPrompt)
            } else if onboarding.currentStep == .chatCoCaptain
                        || onboarding.currentStep == .applyCoCaptainChange {
                if coCaptainHasPendingOnboardingReview {
                    onboarding.moveToStep(.applyCoCaptainChange)
                } else {
                    onboarding.moveToStep(.chatCoCaptain)
                }
            } else if onboarding.currentStep == .chatCoCaptainGameEdit
                        || onboarding.currentStep == .reviewCoCaptainChange {
                onboarding.moveToStep(.chatCoCaptainGameEdit)
            }
        }
    }

    func handleCoCaptainSuccessCountChange() {
        advanceInitialCoCaptainOnboardingIfReady()
    }

    func handleHelpGuidesShownForOnboarding() {
        if onboarding.currentStep == .browseHelpGuides {
            onboarding.completeCurrentStep()
        }
    }

    func handleCoCaptainSheetAppeared() {
        guard coCaptainStartsLarge else { return }
        Task { @MainActor in
            await Task.yield()
            self.coCaptainAllowsMediumDetent = true
        }
    }

    func requestCoCaptainExpandedPresentation() {
        coCaptainAllowsMediumDetent = true
        coCaptainDetent = .large
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
            self.createNode(type: type)
            self.commandPalette.nodes = self.router.activeStore.nodes
        }
        commandPalette.onFlyToNode = { [weak self] nodeId in
            self?.focusCanvasNode(nodeId)
        }
        coCaptain.onFlyToNode = { [weak self] nodeId in
            self?.focusCanvasNode(nodeId)
        }
        coCaptain.onReviewItemApplied = { [weak self] _, _ in
            self?.handleOnboardingReviewApplied()
        }
        coCaptain.onOnboardingReviewFallback = { [weak self] in
            let lessonID = self?.onboarding.activeLessonID?.rawValue ?? OnboardingLessonID.omniboxNavigation.rawValue
            AnalyticsService.shared.logEvent(
                OnboardingAnalytics.cocaptainReviewFallback,
                parameters: [OnboardingAnalytics.lessonID: lessonID]
            )
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
        if let measuredSize = nodeSizes[nodeId] {
            size = measuredSize
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
            guard let self else { return }
            self.router.goBack()
            if self.onboarding.currentStep == .tapGoBackAction {
                self.onboarding.completeCurrentStep()
            }
        }
        actionDispatcher.register(.createNode) { [weak self] in
            self?.createNode(type: .miniApp)
        }
        actionDispatcher.register(.createFirebaseNode) { [weak self] in
            self?.createNode(type: .miniApp)
        }
        actionDispatcher.register(.summonCoCaptain) { [weak self] in
            guard let self else { return }
            self.coCaptain.configureProjectSession(store: self.router.activeStore, dispatcher: self.actionDispatcher)
            self.presentCoCaptain()
        }
        actionDispatcher.register(.summonCopilotVoice) { [weak self] in
            self?.presentCopilotCall(mode: .voice)
        }
        actionDispatcher.register(.summonCopilotVideo) { [weak self] in
            self?.presentCopilotCall(mode: .video)
        }
        actionDispatcher.register(.undo) { [weak self] in
            guard let self else { return }
            self.performUndo(undoManager: self.activeUndoManager)
            if self.onboarding.currentStep == .undoCanvasEdit {
                self.onboarding.completeCurrentStep()
            }
        }
        actionDispatcher.register(.redo) { [weak self] in
            guard let self else { return }
            self.performRedo(undoManager: self.activeUndoManager)
            if self.onboarding.currentStep == .redoCanvasEdit {
                self.onboarding.completeCurrentStep()
            }
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
        actionDispatcher.register(.openUsage) { [weak self] in
            self?.showingUsage = true
        }
        actionDispatcher.register(.openProfile) { [weak self] in
            self?.showingProfile = true
        }
        actionDispatcher.register(.openActivity) { [weak self] in
            self?.showingActivity = true
        }
        actionDispatcher.register(.openDaily) { [weak self] in
            self?.showingDaily = true
        }
        actionDispatcher.register(.openWhatsApp) {
            if let url = SupportContact.whatsAppURL {
                UIApplication.shared.open(url)
            }
        }
        actionDispatcher.register(.help) { [weak self] in
            self?.showingHelp = true
            if self?.onboarding.currentStep == .openHelpCenter {
                self?.onboarding.completeCurrentStep()
            }
        }
        actionDispatcher.register(.openAppIcon) { [weak self] in
            self?.showingAppIconPicker = true
        }
        actionDispatcher.register(.changeCopilot) { [weak self] in
            self?.commandPalette.setPresented(false)
            self?.showingCopilotPicker = true
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
            if self.onboarding.currentStep == .runOrganizeNodes {
                self.onboarding.completeCurrentStep()
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
        } else if showingUsage {
            showingUsage = false
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.3))
                self?.showingPurchaseSheet = true
            }
        } else {
            showingPurchaseSheet = true
        }
    }

    /// Opens the purchase sheet, dismissing any covering sheet first when needed.
    func requestPurchaseSheet() {
        presentPurchaseSheet()
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

        if type == .miniApp,
           let existing = router.activeStore.nodes.first(where: { $0.id == uuid }),
           existing.type != .miniApp,
           !canCreateMiniApp() {
            presentMiniAppLimitReached()
            return
        }

        router.activeStore.updateNodeType(id: uuid, type: type)
    }

    private func createNode(type: NodeType) {
        if type == .miniApp, !canCreateMiniApp() {
            presentMiniAppLimitReached()
            return
        }
        router.activeStore.addNode(type: type)
    }

    private func canCreateMiniApp() -> Bool {
        let subscriptionManager = SubscriptionManager.shared
        let limiter = MiniAppCreationLimiter()
        let count = userMiniAppCount()
        if case .requiresPro = limiter.gate(
            isSubscribed: subscriptionManager.isSubscribed,
            miniAppCount: count
        ) {
            return false
        }
        return true
    }

    func userMiniAppCount() -> Int {
        MiniAppCreationLimiter().countUserMiniApps(
            persistence: ProjectPersistenceService(),
            liveNodesByFileName: router.liveNodesByFileName()
        )
    }

    private func presentMiniAppLimitReached() {
        HapticsManager.shared.notification(.warning)
        showingMiniAppLimitAlert = true
    }

    func focusCanvasNode(_ nodeId: UUID) {
        guard let node = router.activeStore.nodes.first(where: { $0.id == nodeId }) else { return }
        let targetScale = flyToTargetScale(for: node, nodeId: nodeId)
        HapticsManager.shared.trigger(.light)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            viewport.flyTo(nodePosition: node.position, containerSize: containerSize, targetScale: targetScale)
        }
        canvasFocusNodeID = nodeId
        canvasFocusClearTask?.cancel()
        canvasFocusClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, !Task.isCancelled else { return }
            if self.canvasFocusNodeID == nodeId {
                self.canvasFocusNodeID = nil
            }
        }

        if onboarding.currentStep == .searchFlyToNode,
           (nodeId == RootCanvasProvider.pacManNodeID || nodeId == RootCanvasProvider.xoNodeID) {
            onboarding.completeCurrentStep()
        }
    }

    private func submitCoCaptainPrompt(_ prompt: String) {
        if let step = onboarding.currentStep, step.blocksCoCaptainPrompt {
            return
        }
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

    func presentCopilotCall(mode: CopilotInteractionMode) {
        if coCaptain.isPresented {
            coCaptain.setPresented(false)
        }
        commandPalette.setPresented(false)

        let persona = selectedCopilot
        let context = copilotCallProjectContext()
        let viewModel = CopilotCallViewModel(
            mode: mode,
            persona: persona,
            projectContext: context
        )
        viewModel.onDismiss = { [weak self] in
            self?.dismissCopilotCall()
        }
        viewModel.onUpgrade = { [weak self] in
            self?.presentPurchaseSheet()
        }
        copilotCallViewModel = viewModel
        activeCopilotCallMode = mode
        showingCopilotCall = true
    }

    func dismissCopilotCall() {
        showingCopilotCall = false
        let viewModel = copilotCallViewModel
        copilotCallViewModel = nil
        Task {
            await viewModel?.liveService.stop()
        }
    }

    private func copilotCallProjectContext() -> String {
        let store = router.activeStore
        let workspaceLabel: String
        switch router.currentWorkspace {
        case .root:
            workspaceLabel = "root"
        case .project(let fileName):
            workspaceLabel = fileName
        }
        let nodeSummary = store.nodes
            .prefix(12)
            .map { "- \($0.title) (\($0.type.rawValue))" }
            .joined(separator: "\n")
        return """
        Workspace: \(workspaceLabel)
        Node count: \(store.nodes.count)
        Nodes:
        \(nodeSummary)
        """
    }

    private func beginInitialCoCaptainOnboardingWaitIfNeeded() {
        guard onboarding.currentStep == .submitCoCaptainPrompt else { return }
        onboardingInitialCoCaptainSuccessBaseline = coCaptain.successfulAssistantResponseCount
        onboarding.hidePopoverForCurrentStep()
    }

    private func handleOnboardingReviewApplied() {
        guard onboarding.currentStep == .applyCoCaptainChange,
              !coCaptainHasPendingOnboardingReview else {
            return
        }

        let lessonID = onboarding.activeLessonID?.rawValue ?? OnboardingLessonID.omniboxNavigation.rawValue
        AnalyticsService.shared.logEvent(
            OnboardingAnalytics.cocaptainReviewApplied,
            parameters: [OnboardingAnalytics.lessonID: lessonID]
        )

        coCaptain.setPresented(false)

        if onboarding.activeLessonID == .canvasBasics {
            celebrateChallengeCompletion()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard let self,
                      self.onboarding.currentStep == .applyCoCaptainChange else {
                    return
                }
                self.onboarding.completeCurrentStep()
            }
            return
        }

        onboarding.completeCurrentStep()
    }

    private var coCaptainHasPendingOnboardingReview: Bool {
        coCaptain.items.contains { item in
            guard case .reviewBundle(let bundle) = item.content else { return false }
            return bundle.items.contains { $0.status.isUnresolved }
        }
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
