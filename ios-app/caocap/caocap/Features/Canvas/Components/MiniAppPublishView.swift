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

    private var currentNode: SpatialNode {
        store.nodes.first(where: { $0.id == node.id }) ?? node
    }

    private var gate: PublishGate {
        coordinator.gate(isSubscribed: subscriptionManager.isSubscribed, isAnonymous: authManager.isAnonymous)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    content
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Publish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 8) {
            Text(currentNode.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Publish your Mini-App to a live URL, then add it to your Home Screen from Safari.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch gate {
        case .requiresPro:
            gateCard(
                title: "CAOCAP Pro required",
                message: "Publishing to the web is a Pro feature.",
                buttonTitle: "View Pro",
                action: { showPaywall = true }
            )
        case .requiresSignIn:
            gateCard(
                title: "Sign in required",
                message: "Create an account before publishing your Mini-App.",
                buttonTitle: "Sign In",
                action: { showSignIn = true }
            )
        case .ready:
            publishContent
        }
    }

    @ViewBuilder
    private var publishContent: some View {
        if case .finished = coordinator.stage, let url = coordinator.publishURL ?? currentNode.miniApp?.publishURL {
            finishedView(url: url)
        } else if case .error(let message) = coordinator.stage {
            errorView(message: message)
        } else if coordinator.stage == .idle {
            idleView
        } else {
            progressView
        }
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            Toggle("Make repository private", isOn: $coordinator.isRepoPrivate)
                .font(.subheadline)

            Text("Private repos require GitHub Pro for GitHub Pages.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !coordinator.hasGitHubToken {
                Text("Connect GitHub to create a repository and publish your Mini-App.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let existingURL = currentNode.miniApp?.publishURL {
                VStack(spacing: 6) {
                    Text("Last published")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(existingURL)
                        .font(.caption.monospaced())
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: primaryAction) {
                Text(primaryButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
        }
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(stageLabel)
                .font(.headline)
            Text(stageSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func finishedView(url: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Your Mini-App is live!")
                .font(.title3.bold())

            Text(url)
                .font(.caption.monospaced())
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            if PublishCoordinator.hasFirebaseConfig(currentNode) {
                firebaseWarning(host: firebaseHostForWarning)
            }

            Button("Copy Link") {
                UIPasteboard.general.string = url
            }
            .buttonStyle(.bordered)

            Button("Open in Safari") {
                if let link = URL(string: url) {
                    openURL(link)
                }
            }
            .buttonStyle(.borderedProminent)

            DisclosureGroup("Add to Home Screen", isExpanded: $showHomeScreenSteps) {
                VStack(alignment: .leading, spacing: 8) {
                    homeScreenStep(1, "Open the link in Safari (button above).")
                    homeScreenStep(2, "Tap the Share button.")
                    homeScreenStep(3, "Choose Add to Home Screen.")
                }
                .padding(.top, 8)
            }
            .font(.subheadline)

            if currentNode.miniApp?.publishURL != nil {
                Button("Publish Again") {
                    coordinator.reset()
                }
                .font(.footnote)
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Publishing failed")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                coordinator.retry()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func gateCard(title: String, message: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
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

    private var stageLabel: String {
        switch coordinator.stage {
        case .connectingGitHub: return "Connecting GitHub"
        case .creatingRepo: return "Creating repository"
        case .pushingCode: return "Uploading HTML"
        case .enablingPages: return "Enabling GitHub Pages"
        case .waitingForPages: return "Waiting for site to go live"
        default: return "Publishing"
        }
    }

    private var stageSubtitle: String {
        switch coordinator.stage {
        case .connectingGitHub:
            return "Authorize CAOCAP to create a repository on your account."
        case .creatingRepo:
            return "Setting up your GitHub repository."
        case .pushingCode:
            return "Pushing index.html to GitHub."
        case .enablingPages:
            return "Turning on GitHub Pages for your repository."
        case .waitingForPages:
            return "This can take up to a minute on the first publish."
        default:
            return ""
        }
    }

    private func primaryAction() {
        Task {
            if !coordinator.hasGitHubToken {
                await coordinator.connectGitHub()
            } else {
                await coordinator.publish(node: currentNode, store: store)
            }
        }
    }
}
