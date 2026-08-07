import SwiftUI

/// Root view that composes the active workspace canvas, global overlays, and session sheets.
///
/// Session orchestration lives in `AppSessionCoordinator`; this view wires UI only.
/// FAB + call chrome live in a passthrough `UIWindow` above system sheets.
struct ContentView: View {
    @State private var session = AppSessionCoordinator()
    @State private var floatingChrome = GlobalFloatingChromeController()
    @State private var fabAnchorFrame: CGRect = .null
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                workspaceCanvas

                if session.showingHUD {
                    CanvasHUDView(
                        store: session.router.activeStore,
                        viewportScale: session.currentScale,
                        onSignInTapped: { session.showingSignIn = true },
                        onCheckpointsTapped: { session.showingSnapshotBrowser = true }
                    )
                }

                if session.commandPalette.miniAppPreviewContext == nil {
                    CommandPaletteView(viewModel: session.commandPalette)
                }

                KeyboardShortcutBridge(
                    onOpenCommandPalette: {
                        session.commandPalette.setPresented(true)
                    },
                    onSummonCoCaptain: {
                        _ = session.actionDispatcher.perform(.summonCoCaptain, source: .user)
                    },
                    onUndo: {
                        _ = session.actionDispatcher.perform(.undo, source: .user)
                    },
                    onRedo: {
                        _ = session.actionDispatcher.perform(.redo, source: .user)
                    }
                )
            }
            .onboardingTooltipOverlay(
                isCommandPalettePresented: session.commandPalette.isPresented,
                rendersAnchor: { !$0.isCanvasLocal && !$0.isPreviewShellLocal && !$0.isCoCaptainLocal }
            )
            .onboardingExplicitAnchorFrames(fabExplicitAnchorFrames)
            .background(Color.black.ignoresSafeArea())
            .overlay { launchOverlay }
            .overlay { introOverlay }
            .overlay { personalizationOverlay }
            .overlay { updatePromptOverlay }
            .overlay {
                if session.showConfetti {
                    ZStack {
                        ConfettiCelebrationView()
                        VStack {
                            Spacer()
                            TutorialGraduationBanner()
                                .padding(.horizontal, 24)
                                .padding(.bottom, 48)
                        }
                    }
                    .zIndex(95)
                    .transition(.opacity)
                }
            }
            .modifier(AppSheetsModifier(session: session))
            .modifier(AppSessionLifecycle(
                session: session,
                geometry: geometry,
                undoManager: undoManager
            ))
            .onAppear {
                floatingChrome.install(session: session) { frame in
                    fabAnchorFrame = frame
                }
            }
            .onDisappear {
                floatingChrome.uninstall()
            }
        }
    }

    private var fabExplicitAnchorFrames: [OnboardingTooltipAnchor: CGRect] {
        guard !fabAnchorFrame.isNull, !fabAnchorFrame.isEmpty else { return [:] }
        return [.floatingCommandButton: fabAnchorFrame]
    }

    @ViewBuilder
    private var workspaceCanvas: some View {
        switch session.router.currentWorkspace {
        case .root:
            WorkspaceCanvasView(
                store: session.router.rootStore,
                canvasID: "root_canvas",
                viewport: $session.viewport,
                currentScale: $session.currentScale,
                canvasFocusNodeID: session.canvasFocusNodeID,
                commandPalette: session.commandPalette,
                onNodeAction: { session.handleNodeAction($0) },
                onNavigateToSubCanvas: { fileName in
                    session.handleSubCanvasNavigation(fileName: fileName)
                },
                onRecoverUnsupportedProject: {
                    session.router.createFreshMiniAppCanvas()
                },
                onFlyToNode: { session.focusCanvasNode($0) }
            )
        case .project(let fileName):
            WorkspaceCanvasView(
                store: session.router.activeStore,
                canvasID: "project_canvas_\(fileName)",
                viewport: $session.viewport,
                currentScale: $session.currentScale,
                canvasFocusNodeID: session.canvasFocusNodeID,
                commandPalette: session.commandPalette,
                onNodeAction: { session.handleNodeAction($0) },
                onNavigateToSubCanvas: { fileName in
                    session.handleSubCanvasNavigation(fileName: fileName)
                },
                onRecoverUnsupportedProject: {
                    session.router.createFreshMiniAppCanvas()
                },
                onFlyToNode: { session.focusCanvasNode($0) }
            )
        }
    }

    @ViewBuilder
    private var launchOverlay: some View {
        if session.isLaunching {
            LaunchScreenView()
                .transition(.opacity)
                .zIndex(100)
        }
    }

    @ViewBuilder
    private var introOverlay: some View {
        if !session.isLaunching && session.intro.shouldPresent {
            IntroView(coordinator: session.intro) {
                session.finishIntroFlow()
            }
            .transition(.opacity)
            .zIndex(80)
        }
    }

    @ViewBuilder
    private var personalizationOverlay: some View {
        if !session.isLaunching
            && !session.intro.shouldPresent
            && session.personalization.shouldPresent {
            PersonalizationOnboardingView(
                coordinator: session.personalization,
                onBackToIntro: {
                    session.returnToIntroFromPersonalization()
                },
                onFinish: {
                    session.finishPersonalizationFlow()
                }
            )
            .transition(.opacity)
            .zIndex(75)
        }
    }

    @ViewBuilder
    private var updatePromptOverlay: some View {
        if let availableUpdate = session.appUpdateService.availableUpdate,
           session.appUpdateService.shouldPresentUpdatePrompt,
           !session.isLaunching {
            AppUpdatePromptView(update: availableUpdate, onUpdate: {})
                .zIndex(90)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthenticationManager())
}
