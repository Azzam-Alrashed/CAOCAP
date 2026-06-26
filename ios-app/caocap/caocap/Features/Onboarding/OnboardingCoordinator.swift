import SwiftUI
import Observation

/// Drives the first-run onboarding flow. Each step is unlocked by the user
/// performing the actual gesture, so learning happens by doing.
@MainActor
@Observable
public class OnboardingCoordinator {

    // MARK: - Step Definition

    public enum Step: Int, CaseIterable, Comparable {
        /// User must tap the floating command button (FAB) to open the command palette.
        case tapFAB = 0
        /// User must type any text in the omnibox search field.
        case typeCoCaptainPrompt
        /// User must send the typed text to CoCaptain via the prompt row or Return key.
        case submitCoCaptainPrompt
        /// User must type a message inside the CoCaptain chat panel.
        case chatCoCaptain
        /// User must dismiss the CoCaptain panel by tapping Done or dragging it down.
        case dismissCoCaptain
        /// User must long-press the FAB to reveal the quick-action radial menu.
        case longPressFAB

        public static func < (lhs: Step, rhs: Step) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var title: String {
            OnboardingManifest.content(for: self).title
        }

        var message: String {
            OnboardingManifest.content(for: self).message
        }

        var icon: String {
            OnboardingManifest.content(for: self).icon
        }

        var stepLabel: String {
            OnboardingManifest.stepLabel(for: self)
        }
    }

    // MARK: - State

    /// The currently active onboarding step. `nil` means onboarding is complete or skipped.
    public var currentStep: Step? = nil

    /// Whether to show the popover for the current step.
    public var showPopover: Bool = false

    /// Delay before showing the first popover (lets launch screen dismiss first).
    private let initialDelay: TimeInterval = 1.5

    /// Brief pause between steps so the UI settles before the next popover appears.
    private let interStepDelay: TimeInterval = 0.8

    @ObservationIgnored
    private var popoverTask: Task<Void, Never>?

    // MARK: - Persistence

    /// Versioned key so a future onboarding redesign can show the new flow to existing users.
    private static let completedKey = "onboarding_completed_v2"
    /// Persists the last in-progress step so the coordinator could resume mid-flow if needed
    /// (currently always resets to the first step on re-launch for a coherent experience).
    private static let stepKey = "onboarding_current_step_v2"

    public var isCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.completedKey) }
    }

    // MARK: - Lifecycle

    public init() {}

    /// Call once from `ContentView.onAppear` after the launch screen fades.
    public func startIfNeeded() {
        guard !isCompleted else { return }

        // If the user closed the app mid-onboarding, reset back to the beginning for a cohesive flow
        guard let firstStep = OnboardingManifest.firstStep else {
            markComplete()
            return
        }

        currentStep = firstStep
        UserDefaults.standard.set(firstStep.rawValue, forKey: Self.stepKey)

        schedulePopover(after: initialDelay)
    }

    private func schedulePopover(after delay: TimeInterval) {
        popoverTask?.cancel()
        popoverTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            showPopover = true
        }
    }

    // MARK: - Step Completion

    /// Call when the user performs the action for the current step.
    public func completeCurrentStep() {
        guard let step = currentStep else { return }
        showPopover = false

        if let next = OnboardingManifest.nextStep(after: step) {
            UserDefaults.standard.set(next.rawValue, forKey: Self.stepKey)
            currentStep = next
            schedulePopover(after: interStepDelay)
        } else {
            markComplete()
        }
    }

    /// Move directly to a specific step (e.g. when resetting back to Step 1).
    public func moveToStep(_ step: Step) {
        showPopover = false
        currentStep = step
        UserDefaults.standard.set(step.rawValue, forKey: Self.stepKey)
        schedulePopover(after: interStepDelay)
    }

    /// Hide the active popover without advancing the onboarding step.
    public func hidePopoverForCurrentStep() {
        popoverTask?.cancel()
        showPopover = false
    }

    /// Skip the entire onboarding.
    public func skip() {
        popoverTask?.cancel()
        showPopover = false
        markComplete()
    }

    /// Reset onboarding (for Settings).
    public func reset() {
        UserDefaults.standard.removeObject(forKey: Self.completedKey)
        UserDefaults.standard.removeObject(forKey: Self.stepKey)
        currentStep = nil
        showPopover = false
        popoverTask?.cancel()
    }

    private func markComplete() {
        popoverTask?.cancel()
        currentStep = nil
        isCompleted = true
        UserDefaults.standard.removeObject(forKey: Self.stepKey)
    }
}
