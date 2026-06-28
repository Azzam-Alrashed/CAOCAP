import SwiftUI

/// Publish flow for a Mini-App: GitHub repo push, GitHub Pages, Safari Home Screen guide.
struct MiniAppPublishView: View {
    let node: SpatialNode
    let store: ProjectStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AuthenticationManager.self) private var authManager

    @State private var coordinator = PublishCoordinator()
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var showSignIn = false
    @State private var showHomeScreenSteps = false
    @State private var showConfetti = false
    @State private var heroScale: CGFloat = 0.92

    private var currentNode: SpatialNode {
        store.nodes.first(where: { $0.id == node.id }) ?? node
    }

    private var gate: PublishGate {
        coordinator.gate(isSubscribed: subscriptionManager.isSubscribed, isAnonymous: authManager.isAnonymous)
    }

    private var presentation: PublishStagePresentation {
        PublishStagePresentation.make(
            gate: gate,
            stage: coordinator.stage,
            nodeTitle: currentNode.title,
            hasGitHubToken: coordinator.hasGitHubToken,
            hasExistingPublish: currentNode.miniApp?.publishURL != nil,
            errorMessage: errorMessage
        )
    }

    private var errorMessage: String? {
        if case .error(let message) = coordinator.stage { return message }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                Image("SpaceSketchBG")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.55)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        stageHero
                            .padding(.top, 12)

                        VStack(spacing: 12) {
                            Text(presentation.title)
                                .font(.system(size: 28, weight: .heavy))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)

                            Text(presentation.subtitle)
                                .font(.system(size: 17))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 16)

                        if hasStageActions {
                            stageBody
                                .padding(.top, 24)
                        }

                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, 24)
                    .containerRelativeFrame(.horizontal)
                }

                if showConfetti {
                    PublishConfettiView()
                        .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Close")
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PurchaseView()
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .task {
            await subscriptionManager.fetchProducts()
        }
        .onChange(of: coordinator.stage) { _, newStage in
            if case .finished = newStage {
                HapticsManager.shared.notification(.success)
                showConfetti = true
            } else {
                showConfetti = false
            }
            heroScale = 1
        }
        .onAppear {
            heroScale = 1
        }
    }

    private var hasStageActions: Bool {
        switch gate {
        case .requiresPro, .requiresSignIn:
            return true
        case .ready:
            switch coordinator.stage {
            case .connectingGitHub, .creatingRepo, .pushingCode, .enablingPages, .waitingForPages:
                return false
            default:
                return true
            }
        }
    }

    @ViewBuilder
    private var stageHero: some View {
        Group {
            if presentation.showSpinner {
                ProgressView()
                    .controlSize(.large)
            } else {
                Text(presentation.emoji)
                    .font(.system(size: presentation.emojiSize))
                    .scaleEffect(heroScale)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: presentation.emojiSize + 16)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var stageBody: some View {
        switch gate {
        case .requiresPro:
            gateActions(buttonTitle: "View Pro") { showPaywall = true }
        case .requiresSignIn:
            gateActions(buttonTitle: "Sign In") { showSignIn = true }
        case .ready:
            readyStageBody
        }
    }

    @ViewBuilder
    private var readyStageBody: some View {
        switch coordinator.stage {
        case .finished:
            if let url = coordinator.publishURL ?? currentNode.miniApp?.publishURL {
                finishedActions(url: url)
            } else {
                Button("Try Again") {
                    coordinator.retry()
                }
                .publishPrimaryButton(tint: .red)
            }
        case .error:
            Button("Try Again") {
                coordinator.retry()
            }
            .publishPrimaryButton(tint: .red)
        case .idle:
            idleActions
        default:
            EmptyView()
        }
    }

    private var idleActions: some View {
        VStack(spacing: 20) {
            if presentation.showPrivateToggle {
                VStack(spacing: 8) {
                    Toggle("Make repository private", isOn: $coordinator.isRepoPrivate)
                        .font(.system(size: 16, weight: .medium))
                        .tint(.blue)

                    Text("Private repos require GitHub Pro for GitHub Pages.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let existingURL = currentNode.miniApp?.publishURL {
                VStack(spacing: 6) {
                    Text("Last published")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(existingURL)
                        .font(.caption.monospaced())
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button(action: primaryAction) {
                Text(primaryButtonTitle)
            }
            .publishPrimaryButton()
            .disabled(isBusy)
        }
        .frame(maxWidth: .infinity)
    }

    private func finishedActions(url: String) -> some View {
        VStack(spacing: 16) {
            Text("✨ 10 Launch Points")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Text(url)
                .font(.caption.monospaced())
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .textSelection(.enabled)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if PublishCoordinator.hasFirebaseConfig(currentNode) {
                firebaseWarning(host: firebaseHostForWarning)
            }

            Button("Open in Safari") {
                if let link = URL(string: url) {
                    openURL(link)
                }
            }
            .publishPrimaryButton()

            Button("Copy Link") {
                UIPasteboard.general.string = url
                HapticsManager.shared.notification(.success)
            }
            .publishSecondaryButton()

            DisclosureGroup("Add to Home Screen", isExpanded: $showHomeScreenSteps) {
                VStack(alignment: .leading, spacing: 8) {
                    homeScreenStep(1, "Open the link in Safari (button above).")
                    homeScreenStep(2, "Tap the Share button.")
                    homeScreenStep(3, "Choose Add to Home Screen.")
                }
                .padding(.top, 8)
            }
            .font(.subheadline)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if currentNode.miniApp?.publishURL != nil {
                Button("Publish Again") {
                    showConfetti = false
                    coordinator.reset()
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func gateActions(buttonTitle: String, action: @escaping () -> Void) -> some View {
        Button(buttonTitle, action: action)
            .publishPrimaryButton()
            .padding(.top, 8)
    }

    private func firebaseWarning(host: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("If this Mini-App uses Firebase, add `\(host)` to your Firebase project's authorized domains.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func homeScreenStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
            Text(text)
        }
        .font(.footnote)
    }

    private var primaryButtonTitle: String {
        if !coordinator.hasGitHubToken {
            return "Connect GitHub"
        }
        return currentNode.miniApp?.publishURL == nil ? "Publish Now" : "Republish"
    }

    private var firebaseHostForWarning: String {
        if let owner = currentNode.miniApp?.githubRepoOwner {
            return PublishCoordinator.firebaseHost(forOwner: owner)
        }
        if let url = coordinator.publishURL ?? currentNode.miniApp?.publishURL,
           let host = PublishCoordinator.firebaseHostname(from: url) {
            return host
        }
        return "your-username.github.io"
    }

    private var isBusy: Bool {
        switch coordinator.stage {
        case .connectingGitHub, .creatingRepo, .pushingCode, .enablingPages, .waitingForPages:
            return true
        default:
            return false
        }
    }

    private func primaryAction() {
        heroScale = 0.92
        Task {
            if !coordinator.hasGitHubToken {
                await coordinator.connectGitHub()
            } else {
                await coordinator.publish(node: currentNode, store: store)
            }
        }
    }
}

private struct PublishStagePresentation {
    let emoji: String
    let emojiSize: CGFloat
    let title: String
    let subtitle: String
    let showSpinner: Bool
    let showPrivateToggle: Bool

    static func make(
        gate: PublishGate,
        stage: PublishStage,
        nodeTitle: String,
        hasGitHubToken: Bool,
        hasExistingPublish: Bool,
        errorMessage: String?
    ) -> PublishStagePresentation {
        switch gate {
        case .requiresPro:
            return PublishStagePresentation(
                emoji: "⭐️",
                emojiSize: 80,
                title: "CAOCAP Pro required",
                subtitle: "Publishing to the web is a Pro feature. Upgrade to launch your Mini-App.",
                showSpinner: false,
                showPrivateToggle: false
            )
        case .requiresSignIn:
            return PublishStagePresentation(
                emoji: "👋",
                emojiSize: 80,
                title: "Sign in to publish",
                subtitle: "Create an account before sharing your Mini-App with the world.",
                showSpinner: false,
                showPrivateToggle: false
            )
        case .ready:
            break
        }

        switch stage {
        case .idle:
            return PublishStagePresentation(
                emoji: "🚀",
                emojiSize: 80,
                title: hasExistingPublish ? "Update your web app!" : "Publish your web app!",
                subtitle: hasGitHubToken
                    ? "Ship \(nodeTitle) to GitHub Pages, then add it to your Home Screen from Safari."
                    : "Connect GitHub to publish \(nodeTitle) live on the web.",
                showSpinner: false,
                showPrivateToggle: hasGitHubToken
            )
        case .connectingGitHub:
            return PublishStagePresentation(
                emoji: "⏳",
                emojiSize: 80,
                title: "Connecting...",
                subtitle: "Authenticating with your GitHub account.",
                showSpinner: true,
                showPrivateToggle: false
            )
        case .creatingRepo:
            return PublishStagePresentation(
                emoji: "⚙️",
                emojiSize: 80,
                title: "Preparing...",
                subtitle: "Creating your repository on GitHub.",
                showSpinner: true,
                showPrivateToggle: false
            )
        case .pushingCode:
            return PublishStagePresentation(
                emoji: "📡",
                emojiSize: 80,
                title: "Uploading...",
                subtitle: "Pushing your HTML into the repository.",
                showSpinner: true,
                showPrivateToggle: false
            )
        case .enablingPages:
            return PublishStagePresentation(
                emoji: "🌐",
                emojiSize: 80,
                title: "Enabling Pages...",
                subtitle: "Turning on GitHub Pages for your repository.",
                showSpinner: true,
                showPrivateToggle: false
            )
        case .waitingForPages:
            return PublishStagePresentation(
                emoji: "🌍",
                emojiSize: 80,
                title: "Going live...",
                subtitle: "Your web app will be ready in a moment.",
                showSpinner: true,
                showPrivateToggle: false
            )
        case .finished:
            return PublishStagePresentation(
                emoji: "🎉",
                emojiSize: 88,
                title: "You've published your web app!",
                subtitle: "Your Mini-App is live on the web.",
                showSpinner: false,
                showPrivateToggle: false
            )
        case .error:
            return PublishStagePresentation(
                emoji: "⚠️",
                emojiSize: 80,
                title: "Publishing failed",
                subtitle: errorMessage ?? "Something went wrong while publishing.",
                showSpinner: false,
                showPrivateToggle: false
            )
        }
    }
}
