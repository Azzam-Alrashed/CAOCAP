import Foundation
import FirebaseAuth
import OSLog
import Observation

// MARK: - Auth State

/// Represents the current authentication state of the user.
enum AuthState: Equatable {
    /// No auth session exists yet. The app is checking for an existing user.
    case loading
    /// The user is signed in anonymously.
    case anonymous(uid: String)
    /// The user has a verified, linked identity (e.g. Sign in with Apple).
    case authenticated(uid: String)
    /// Sign-in failed and there is no valid session.
    case failed(reason: String)
}

// MARK: - AuthenticationManager

/// Manages the full Firebase authentication lifecycle.
///
/// Responsibilities:
///  - Silently signs in new users anonymously on first launch.
///  - Restores existing sessions on subsequent launches (no round-trip to Firebase needed).
///  - Exposes reactive `authState` for the UI to observe.
///  - Will be extended to support Sign in with Apple account linking.
///
/// Inject via SwiftUI Environment:
/// ```swift
/// @Environment(AuthenticationManager.self) private var authManager
/// ```
@Observable
@MainActor
final class AuthenticationManager {

    // MARK: Public State

    private(set) var authState: AuthState = .loading

    /// Convenience accessor — true if the user has any valid session.
    var isSignedIn: Bool {
        switch authState {
        case .anonymous, .authenticated: return true
        case .loading, .failed: return false
        }
    }

    var currentUID: String? {
        switch authState {
        case .anonymous(let uid), .authenticated(let uid): return uid
        case .loading, .failed: return nil
        }
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.ficruty.caocap", category: "Auth")

    /// Wraps the Firebase listener handle so it can be safely cancelled
    /// from `deinit`, which is always nonisolated in Swift 6.
    private final class ListenerCanceller {
        var handle: AuthStateDidChangeListenerHandle?
        deinit {
            if let handle {
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }
    private let listenerCanceller = ListenerCanceller()

    // MARK: Lifecycle

    init() {}

    // MARK: - Bootstrap

    /// Starts the auth flow. Called once from `AppConfiguration`.
    ///
    /// Attaches a Firebase listener so `authState` stays in sync with
    /// the real session without requiring manual polling.
    func start() {
        listenerCanceller.handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.handle(user: user)
            }
        }
    }

    // MARK: - Anonymous Sign-In

    /// Signs in anonymously. Safe to call multiple times — no-ops if already signed in.
    func signInAnonymously() async {
        guard !isSignedIn else {
            logger.debug("Already signed in — skipping anonymous sign-in.")
            return
        }

        do {
            let result = try await Auth.auth().signInAnonymously()
            logger.info("Anonymous sign-in succeeded. UID: \(result.user.uid)")
            // authState is updated automatically via the listener
        } catch {
            logger.error("Anonymous sign-in failed: \(error.localizedDescription)")
            authState = .failed(reason: error.localizedDescription)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            logger.info("User signed out.")
        } catch {
            logger.error("Sign out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func handle(user: User?) {
        guard let user else {
            logger.info("No active session found. Will attempt anonymous sign-in.")
            authState = .loading
            Task { await signInAnonymously() }
            return
        }

        if user.isAnonymous {
            authState = .anonymous(uid: user.uid)
            logger.info("Session restored: anonymous user \(user.uid)")
        } else {
            authState = .authenticated(uid: user.uid)
            logger.info("Session restored: authenticated user \(user.uid)")
        }
    }
}
