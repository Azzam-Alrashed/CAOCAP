import SwiftUI
import Observation

/// Drives the first-run onboarding flow. Each step is unlocked by the user
/// performing the actual gesture, so learning happens by doing.
@MainActor
@Observable
public class OnboardingCoordinator {

    // MARK: - Step Definition

    public enum Step: Int, CaseIterable, Comparable {
        case tapFAB = 0
        case typeCoCaptainPrompt
        case submitCoCaptainPrompt
        case chatCoCaptain
        case dismissCoCaptain
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

    private static let completedKey = "onboarding_completed_v2"
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
