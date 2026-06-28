import SwiftUI

/// Root view that composes the active workspace canvas, global overlays, and session sheets.
///
/// Session orchestration lives in `AppSessionCoordinator`; this view wires UI only.
struct ContentView: View {
    @State private var session = AppSessionCoordinator()
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

                floatingCommandButtonView
                    .environment(\.layoutDirection, .leftToRight)

                CommandPaletteView(viewModel: session.commandPalette)

                KeyboardShortcutBridge(
                    onOpenCommandPalette: {
                        session.commandPalette.setPresented(true)
                    },
                    onSummonCoCaptain: {
                        _ = session.actionDispatcher.perform(.summonCoCaptain, source: .user)
                    },
                    onUndo: {
                        session.performUndo(undoManager: undoManager)
                    },
                    onRedo: {
                        session.performRedo(undoManager: undoManager)
                    }
                )
            }
            .onboardingTooltipOverlay()
            .background(Color.black.ignoresSafeArea())
            .overlay { launchOverlay }
            .overlay { introOverlay }
            .overlay { personalizationOverlay }
            .overlay { updatePromptOverlay }
            .overlay {
                if session.showConfetti {
                    ConfettiCelebrationView()
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
        }
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
                onNodeAction: { session.handleNodeAction($0) },
                onNavigateToSubCanvas: { fileName in
                    session.handleSubCanvasNavigation(fileName: fileName)
                },
                onRecoverUnsupportedProject: {
                    session.router.createFreshMiniAppCanvas()
                }
            )
        case .project(let fileName):
            WorkspaceCanvasView(
                store: session.router.activeStore,
                canvasID: "project_canvas_\(fileName)",
                viewport: $session.viewport,
                currentScale: $session.currentScale,
                onNodeAction: { session.handleNodeAction($0) },
                onNavigateToSubCanvas: { fileName in
                    session.handleSubCanvasNavigation(fileName: fileName)
                },
                onRecoverUnsupportedProject: {
                    session.router.createFreshMiniAppCanvas()
                }
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
            PersonalizationOnboardingView(coordinator: session.personalization) {
                session.finishPersonalizationFlow()
            }
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

    private var floatingCommandButtonView: some View {
        FloatingCommandButton(
            onTap: {
                session.commandPalette.setPresented(true)
            },
            onUndo: {
                session.performUndo(undoManager: undoManager)
            },
            onSummonCoCaptain: {
                _ = session.actionDispatcher.perform(.summonCoCaptain, source: .user)
            },
            onRedo: {
                session.performRedo(undoManager: undoManager)
            },
            canUndo: (session.router.activeStore.undoStackChanged >= 0) && (undoManager?.canUndo ?? false),
            canRedo: (session.router.activeStore.undoStackChanged >= 0) && (undoManager?.canRedo ?? false),
            onExpand: {
                if session.onboarding.currentStep == .longPressFAB {
                    session.onboarding.completeCurrentStep()
                }
            },
            onDragSummon: {
                if session.onboarding.currentStep == .longPressFAB {
                    session.onboarding.completeCurrentStep()
                }
            },
            isOnboardingHighlighted: session.onboarding.showPopover &&
                (session.onboarding.currentStep == .tapFAB || session.onboarding.currentStep == .longPressFAB)
        )
    }
}

#Preview {
    ContentView()
        .environment(AuthenticationManager())
}
