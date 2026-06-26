import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

// MARK: - AppleSignInCoordinator

/// Handles the ASAuthorizationController flow and produces a Firebase OAuthCredential.
///
/// Usage:
/// ```swift
/// let coordinator = AppleSignInCoordinator()
/// let credential = try await coordinator.signIn()
/// try await authManager.signInWithApple(credential: credential)
/// ```
@MainActor
final class AppleSignInCoordinator: NSObject {

    private var continuation: CheckedContinuation<OAuthCredential, Error>?

    /// A random nonce used to prevent replay attacks. Must be sent to Apple
    /// and verified against the returned identity token.
    private var currentNonce: String?

    // MARK: - Public

    /// Presents Apple's native authorization sheet and resumes with a Firebase
    /// credential that can be linked to the current anonymous user.
    func signIn() async throws -> OAuthCredential {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let nonce = randomNonce()
            self.currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce Helpers

    /// Generates the raw nonce Firebase will later verify against Apple's token.
    /// Generates the raw nonce Firebase will later verify against Apple's token.
    /// - Parameter length: The byte length of the nonce. Defaults to 32.
    /// - Returns: A hex-encoded string representation of the random bytes.
    private func randomNonce(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Computes the SHA-256 hash of a given string.
    /// - Parameter input: The string to hash (e.g. the raw nonce).
    /// - Returns: A hex-encoded string of the computed hash.
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {

    /// Invoked when the Apple Sign-In flow completes successfully.
    /// Validates the returned credentials and resumes the continuation with a Firebase `OAuthCredential`.
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = self.currentNonce,
                let appleIDToken = appleIDCredential.identityToken,
                let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else {
                self.continuation?.resume(throwing: AuthError.invalidAppleCredential)
                self.continuation = nil
                return
            }

            // Firebase needs the original raw nonce, not the SHA-256 value sent
            // to Apple, to validate that this response belongs to our request.
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            self.continuation?.resume(returning: credential)
            self.continuation = nil
        }
    }

    /// Invoked when the Apple Sign-In flow fails or is canceled by the user.
    /// Resumes the continuation by throwing the encountered error.
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // ASAuthorizationController always calls this on the main thread.
        // assumeIsolated bridges the nonisolated protocol requirement to @MainActor.
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.windows.first { $0.isKeyWindow } ?? UIWindow()
        }
    }
}

// MARK: - AuthError

/// Custom errors thrown during the Apple Sign-In orchestration.
enum AuthError: LocalizedError {
    /// Thrown when Apple returns an incomplete or unparseable credential.
    case invalidAppleCredential
    /// Thrown when no foreground window scene is available to present the ASAuthorizationController.
    case missingPresentingViewController

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return LocalizationManager.shared.localizedString("Could not validate Apple ID credential. Please try again.")
        case .missingPresentingViewController:
            return LocalizationManager.shared.localizedString("No view controller available to present sign-in flow.")
        }
    }
}
