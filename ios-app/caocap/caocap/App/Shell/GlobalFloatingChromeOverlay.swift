import SwiftUI
import UIKit

/// Transparent window that sits above system sheets and only accepts hits inside
/// explicitly registered chrome frames (FAB, call pill, expanded FAB menu).
@MainActor
final class PassthroughChromeWindow: UIWindow {
    /// Screen-space rects that should receive touches. Everything else passes through.
    var interactiveFrames: [CGRect] = []

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let allowed = interactiveFrames.contains { frame in
            frame.insetBy(dx: -6, dy: -6).contains(point)
        }
        guard allowed else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// Shared closures + session pointer so the overlay hosting controller is created once
/// and keeps SwiftUI `@State` (FAB dock position) across session observation updates.
@Observable
@MainActor
final class GlobalFloatingChromeBridge {
    var session: AppSessionCoordinator?
    var onInteractiveFramesChange: ([CGRect]) -> Void = { _ in }
    var onFABFrameChange: (CGRect) -> Void = { _ in }
}

/// Owns the high-level chrome window and refreshes its SwiftUI root.
@MainActor
final class GlobalFloatingChromeController {
    private var window: PassthroughChromeWindow?
    private var hostingController: UIHostingController<GlobalFloatingChromeView>?
    private let bridge = GlobalFloatingChromeBridge()

    func install(session: AppSessionCoordinator, onFABFrameChange: @escaping (CGRect) -> Void) {
        bridge.session = session
        bridge.onFABFrameChange = onFABFrameChange
        bridge.onInteractiveFramesChange = { [weak self] frames in
            self?.window?.interactiveFrames = frames
        }

        guard window == nil else { return }
        guard let scene = activeWindowScene() else { return }

        let hosting = UIHostingController(rootView: GlobalFloatingChromeView(bridge: bridge))
        hosting.view.backgroundColor = .clear
        hostingController = hosting

        let overlay = PassthroughChromeWindow(windowScene: scene)
        overlay.windowLevel = .alert + 1
        overlay.backgroundColor = .clear
        overlay.rootViewController = hosting
        overlay.isHidden = false
        window = overlay
    }

    func uninstall() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        hostingController = nil
        bridge.session = nil
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}

/// FAB + optional call chrome rendered in the overlay window above sheets.
struct GlobalFloatingChromeView: View {
    @Bindable var bridge: GlobalFloatingChromeBridge

    @State private var callChromeFrame: CGRect = .null
    @State private var fabInteractiveFrame: CGRect = .null

    var body: some View {
        Group {
            if let session = bridge.session {
                chromeBody(session: session)
            } else {
                Color.clear
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func chromeBody(session: AppSessionCoordinator) -> some View {
        @Bindable var session = session
        ZStack {
            if shouldShowChrome(session) {
                FloatingCommandButton(
                    onTap: {
                        session.commandPalette.setPresented(true)
                    },
                    onSelectMode: { mode in
                        switch mode {
                        case .chat:
                            _ = session.actionDispatcher.perform(.summonCoCaptain, source: .user)
                        case .voice:
                            _ = session.actionDispatcher.perform(.summonCopilotVoice, source: .user)
                        case .video:
                            _ = session.actionDispatcher.perform(.summonCopilotVideo, source: .user)
                        }
                    },
                    copilot: session.selectedCopilot,
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
                    isOnboardingHighlighted: session.onboarding.showPopover && (
                        session.onboarding.currentStep == .tapFAB
                        || session.onboarding.currentStep == .longPressFAB
                        || session.onboarding.currentStep == .runOrganizeNodes
                        || (session.onboarding.currentStep == .undoCanvasEdit && !session.commandPalette.isPresented)
                        || (session.onboarding.currentStep == .redoCanvasEdit && !session.commandPalette.isPresented)
                        || (session.onboarding.currentStep == .searchFlyToNode && !session.commandPalette.isPresented)
                        || (session.onboarding.currentStep == .returnToRoot && !session.commandPalette.isPresented)
                        || (session.onboarding.currentStep == .typeGoBackInOmnibox && !session.commandPalette.isPresented)
                        || (session.onboarding.currentStep == .tapGoBackAction && !session.commandPalette.isPresented)
                    ),
                    obstacleFrame: session.showingCopilotCall ? callChromeFrame : .null,
                    onInteractiveFrameChange: { frame in
                        fabInteractiveFrame = frame
                        publishInteractiveFrames(session: session)
                    },
                    onAnchorFrameChange: { frame in
                        bridge.onFABFrameChange(frame)
                    }
                )
                .environment(\.layoutDirection, .leftToRight)
                .environment(session.onboarding)

                if session.showingCopilotCall, let callViewModel = session.copilotCallViewModel {
                    CopilotCallView(
                        viewModel: callViewModel,
                        onFrameChange: { frame in
                            callChromeFrame = frame
                            publishInteractiveFrames(session: session)
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            publishInteractiveFrames(session: session)
        }
        .onChange(of: session.showingCopilotCall) { _, showing in
            if !showing {
                callChromeFrame = .null
                publishInteractiveFrames(session: session)
            }
        }
        .onChange(of: session.isLaunching) { _, _ in
            refreshChromeVisibility(session: session)
        }
        .onChange(of: session.intro.shouldPresent) { _, _ in
            refreshChromeVisibility(session: session)
        }
        .onChange(of: session.personalization.shouldPresent) { _, _ in
            refreshChromeVisibility(session: session)
        }
    }

    private func shouldShowChrome(_ session: AppSessionCoordinator) -> Bool {
        !session.isLaunching
            && !session.intro.shouldPresent
            && !session.personalization.shouldPresent
    }

    private func refreshChromeVisibility(session: AppSessionCoordinator) {
        if !shouldShowChrome(session) {
            fabInteractiveFrame = .null
            callChromeFrame = .null
            bridge.onFABFrameChange(.null)
        }
        publishInteractiveFrames(session: session)
    }

    private func publishInteractiveFrames(session: AppSessionCoordinator) {
        guard shouldShowChrome(session) else {
            bridge.onInteractiveFramesChange([])
            return
        }
        var frames: [CGRect] = []
        if !fabInteractiveFrame.isNull, !fabInteractiveFrame.isEmpty {
            frames.append(fabInteractiveFrame)
        }
        if session.showingCopilotCall, !callChromeFrame.isNull, !callChromeFrame.isEmpty {
            frames.append(callChromeFrame)
        }
        bridge.onInteractiveFramesChange(frames)
    }
}
