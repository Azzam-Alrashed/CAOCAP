import AuthenticationServices
import Foundation
import OSLog
import UIKit

enum GitHubAuthError: LocalizedError {
    case missingSecrets
    case authenticationFailed
    case userCanceled
    case invalidResponse
    case tokenExtractionFailed

    var errorDescription: String? {
        switch self {
        case .missingSecrets:
            return "Publishing is not configured. Add Secrets.plist with GitHub credentials."
        case .authenticationFailed:
            return "GitHub authentication failed."
        case .userCanceled:
            return "GitHub sign-in was canceled."
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case .tokenExtractionFailed:
            return "Could not read the GitHub access token."
        }
    }
}

/// OAuth flow for GitHub repo access during Mini-App publish (separate from Firebase GitHub sign-in).
@MainActor
final class GitHubAuthService: NSObject {
    static let shared = GitHubAuthService()

    private let logger = Logger(subsystem: "com.caocap.app", category: "GitHubAuth")
    private var authSession: ASWebAuthenticationSession?

    private let authorizeURL = "https://github.com/login/oauth/authorize"
    private let tokenURL = "https://github.com/login/oauth/access_token"
    private let callbackScheme = "caocap"

    private override init() {
        super.init()
    }

    func authenticate() async throws -> String {
        let (clientId, clientSecret) = try loadGitHubSecrets()

        var components = URLComponents(string: authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: "repo read:user")
        ]

        guard let url = components.url else { throw GitHubAuthError.invalidResponse }

        let code = try await getAuthorizationCode(url: url)
        let token = try await exchangeCodeForToken(code: code, clientId: clientId, clientSecret: clientSecret)
        KeychainService.save(token: token, for: KeychainService.githubPublishTokenAccount)
        return token
    }

    func storedToken() -> String? {
        KeychainService.getToken(for: KeychainService.githubPublishTokenAccount)
    }

    func disconnect() {
        KeychainService.deleteToken(for: KeychainService.githubPublishTokenAccount)
    }

    private func loadGitHubSecrets() throws -> (String, String) {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let secrets = NSDictionary(contentsOfFile: path) as? [String: Any],
              let clientId = secrets["GITHUB_CLIENT_ID"] as? String,
              let clientSecret = secrets["GITHUB_CLIENT_SECRET"] as? String,
              !clientId.isEmpty, clientId != "PASTE_YOUR_GITHUB_CLIENT_ID_HERE",
              !clientSecret.isEmpty, clientSecret != "PASTE_YOUR_GITHUB_CLIENT_SECRET_HERE" else {
            throw GitHubAuthError.missingSecrets
        }
        return (clientId, clientSecret)
    }

    private func getAuthorizationCode(url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                        continuation.resume(throwing: GitHubAuthError.userCanceled)
                    } else {
                        self.logger.error("GitHub auth session error: \(error.localizedDescription)")
                        continuation.resume(throwing: GitHubAuthError.authenticationFailed)
                    }
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: GitHubAuthError.invalidResponse)
                    return
                }

                continuation.resume(returning: code)
            }

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.start()
        }
    }

    private func exchangeCodeForToken(code: String, clientId: String, clientSecret: String) async throws -> String {
        guard let url = URL(string: tokenURL) else { throw GitHubAuthError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "client_id=\(clientId)&client_secret=\(clientSecret)&code=\(code)"
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubAuthError.authenticationFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw GitHubAuthError.tokenExtractionFailed
        }

        return accessToken
    }
}

extension GitHubAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }
}
