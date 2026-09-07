import AuthenticationServices
import FirebaseAuth
import Observation
import OSLog

enum MacAuthState: Equatable {
    case signedOut
    case signedIn(uid: String)
    case failed(message: String)
}

/// Owns the Mac Firebase session. Provider-linked Apple accounts only.
///
/// Never creates an anonymous user. An anonymous or missing session is
/// treated as signed out so iOS and Mac can share one account later.
@Observable
@MainActor
final class AuthenticationManager {
    private(set) var authState: MacAuthState = .signedOut
    private(set) var isSigningIn = false

    private let logger = Logger(subsystem: "com.caocap.app", category: "Auth")
    private let appleSignIn = AppleSignInCoordinator()
    private let listenerCanceller = ListenerCanceller()

    func start() {
        guard listenerCanceller.handle == nil else { return }
        listenerCanceller.handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.apply(user)
            }
        }
    }

    func signInWithApple() async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let credential = try await appleSignIn.signIn()
            _ = try await Auth.auth().signIn(with: credential)
            logger.info("Apple sign-in succeeded.")
        } catch {
            if Self.isUserCancellation(error) {
                authState = .signedOut
                logger.info("Apple sign-in canceled.")
                return
            }
            logger.error("Apple sign-in failed: \(error.localizedDescription, privacy: .public)")
            authState = .failed(message: error.localizedDescription)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            authState = .signedOut
            logger.info("User signed out.")
        } catch {
            logger.error("Sign out failed: \(error.localizedDescription, privacy: .public)")
            authState = .failed(message: error.localizedDescription)
        }
    }

    private func apply(_ user: User?) {
        if let user {
            if user.isAnonymous {
                logger.warning("Rejected anonymous Firebase session.")
                signOutAnonymousUser()
                return
            }
            authState = .signedIn(uid: user.uid)
            logger.info("Authenticated session restored.")
            return
        }

        if case .failed = authState { return }
        authState = .signedOut
    }

    private func signOutAnonymousUser() {
        do {
            try Auth.auth().signOut()
        } catch {
            logger.error("Failed to clear anonymous session: \(error.localizedDescription, privacy: .public)")
        }
        authState = .signedOut
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        if case AppleSignInError.canceled = error {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.canceled.rawValue
    }

    private final class ListenerCanceller: @unchecked Sendable {
        var handle: AuthStateDidChangeListenerHandle?
        deinit {
            if let handle {
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }
}
