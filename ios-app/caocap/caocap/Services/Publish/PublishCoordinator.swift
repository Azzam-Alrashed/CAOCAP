import Foundation
import Observation
import OSLog

enum PublishStage: Equatable {
    case idle
    case connectingGitHub
    case creatingRepo
    case pushingCode
    case deployingVercel
    case finished
    case error(String)
}

enum PublishGate: Equatable {
    case ready
    case requiresPro
    case requiresSignIn
}

/// Orchestrates GitHub push + Vercel deploy for a single Mini-App node.
@MainActor
@Observable
final class PublishCoordinator {
    private let logger = Logger(subsystem: "com.caocap.app", category: "PublishCoordinator")
    private let htmlCompiler = PublishHTMLCompiler()
    private let githubService = GitHubService()
    private let vercelService = VercelPublishService()

    var stage: PublishStage = .idle
    var publishURL: String?
    var isRepoPrivate = false
    var hasGitHubToken: Bool

    init() {
        hasGitHubToken = GitHubAuthService.shared.storedToken() != nil
    }

    func gate(isSubscribed: Bool, isAnonymous: Bool) -> PublishGate {
        if !isSubscribed { return .requiresPro }
        if isAnonymous { return .requiresSignIn }
        return .ready
    }

    func connectGitHub() async {
        stage = .connectingGitHub
        do {
            _ = try await GitHubAuthService.shared.authenticate()
            hasGitHubToken = true
            stage = .idle
        } catch let error as GitHubAuthError {
            if case .userCanceled = error {
                stage = .idle
            } else {
                stage = .error(error.localizedDescription)
            }
        } catch {
            stage = .error(error.localizedDescription)
        }
    }

    func publish(node: SpatialNode, store: ProjectStore) async {
        guard node.type == .miniApp else {
            stage = .error("Only Mini-App nodes can be published.")
            return
        }

        guard let html = htmlCompiler.compileForPublish(node: node), !html.isEmpty else {
            stage = .error("No compiled HTML to publish. Add code to this Mini-App first.")
            return
        }

        guard let token = GitHubAuthService.shared.storedToken() else {
            stage = .error("Connect GitHub before publishing.")
            return
        }

        let existingOwner = node.miniApp?.githubRepoOwner
        let existingName = node.miniApp?.githubRepoName
        let repoName = existingName ?? PublishRepoNaming.repositoryName(nodeTitle: node.title, nodeID: node.id)

        do {
            let owner: String
            let repo: GitHubRepo

            if let existingOwner, let existingName, let repoId = node.miniApp?.githubRepoId {
                owner = existingOwner
                repo = GitHubRepo(
                    id: repoId,
                    name: existingName,
                    htmlUrl: "https://github.com/\(existingOwner)/\(existingName)",
                    private: isRepoPrivate,
                    cloneUrl: "https://github.com/\(existingOwner)/\(existingName).git"
                )
                stage = .pushingCode
            } else {
                stage = .creatingRepo
                let githubOwner = try await githubService.getAuthenticatedUser(token: token)
                owner = githubOwner
                repo = try await githubService.createRepository(
                    name: repoName,
                    isPrivate: isRepoPrivate,
                    token: token
                )
                stage = .pushingCode
            }

            let commitMessage = existingName == nil ? "Initial publish from CAOCAP" : "Update from CAOCAP"
            try await githubService.createOrUpdateFile(
                owner: owner,
                repo: repo.name,
                path: "index.html",
                content: html,
                message: commitMessage,
                token: token
            )

            stage = .deployingVercel
            let liveURL = try await vercelService.deployFromGitHub(repoId: repo.id, projectName: repo.name)

            store.updateMiniAppPublishMetadata(
                id: node.id,
                publishURL: liveURL,
                githubRepoOwner: owner,
                githubRepoName: repo.name,
                githubRepoId: repo.id,
                isPrivate: isRepoPrivate
            )

            publishURL = liveURL
            stage = .finished
        } catch let error as VercelPublishError {
            stage = .error(error.localizedDescription)
        } catch let error as GitHubAuthError {
            stage = .error(error.localizedDescription)
        } catch {
            logger.error("Publish failed: \(error.localizedDescription)")
            stage = .error(error.localizedDescription)
        }
    }

    func reset() {
        stage = .idle
        publishURL = nil
    }

    func retry() {
        stage = .idle
    }

    static func firebaseHostname(from publishURL: String) -> String? {
        guard let url = URL(string: publishURL), let host = url.host else { return nil }
        return host
    }

    static func hasFirebaseConfig(_ node: SpatialNode) -> Bool {
        guard let text = node.miniApp?.firebaseConfigText else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
