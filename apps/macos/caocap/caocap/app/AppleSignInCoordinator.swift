import AppKit
import AuthenticationServices
import CryptoKit
import FirebaseAuth

enum AppleSignInError: LocalizedError, Equatable {
    case invalidAppleCredential
    case canceled

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return "Could not validate the Apple ID credential. Please try again."
        case .canceled:
            return "Sign in with Apple was canceled."
        }
    }
}

/// Presents Sign in with Apple and returns a Firebase credential.
@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<OAuthCredential, Error>?
    private var currentNonce: String?
    private var fallbackWindow: NSWindow?

    func signIn() async throws -> OAuthCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let nonce = randomNonce()
            currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func randomNonce(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func resume(_ result: Result<OAuthCredential, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        currentNonce = nil
        switch result {
        case .success(let credential):
            continuation.resume(returning: credential)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func presentationWindow() -> NSWindow {
        if let keyWindow = NSApp.keyWindow {
            return keyWindow
        }
        if let hub = NSApp.windows.first(where: { window in
            !(window is CompanionPanel)
                && window.canBecomeMain
                && window.level == .normal
        }) {
            return hub
        }
        if let fallbackWindow {
            return fallbackWindow
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        fallbackWindow = window
        return window
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let appleIDToken = appleIDCredential.identityToken,
                let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else {
                resume(.failure(AppleSignInError.invalidAppleCredential))
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            resume(.success(credential))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                resume(.failure(AppleSignInError.canceled))
                return
            }
            resume(.failure(error))
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            presentationWindow()
        }
    }
}
