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
        case searchBarCoCaptain
        case chatCoCaptain
        case dismissCoCaptain
        case longPressFAB

        public static func < (lhs: Step, rhs: Step) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var title: String {
            switch self {
            case .tapFAB:             return "Your Command Center"
            case .searchBarCoCaptain: return "Ask CoCaptain"
            case .chatCoCaptain:      return "Meet Your Co-pilot"
            case .dismissCoCaptain:   return "Back to Canvas"
            case .longPressFAB:       return "Quick Shortcuts"
            }
        }

        var message: String {
            switch self {
            case .tapFAB:
                return "Tap this button to open the command palette — your gateway to every action in CAOCAP."
            case .searchBarCoCaptain:
                return "Type a message like 'hi' here and press return to send it to your AI pilot."
            case .chatCoCaptain:
                return "CoCaptain is here! Type a message here to build, refine, or explain code."
            case .dismissCoCaptain:
                return "Tap 'Done' or drag the panel down to close CoCaptain and return to the canvas."
            case .longPressFAB:
                return "Press and hold this button to reveal quick actions, or drag to the sparkles ✦ to quickly summon CoCaptain."
            }
        }

        var icon: String {
            switch self {
            case .tapFAB:             return "hand.tap"
            case .searchBarCoCaptain: return "keyboard"
            case .chatCoCaptain:      return "bubble.left.and.text.bubble.right"
            case .dismissCoCaptain:   return "arrow.down"
            case .longPressFAB:       return "hand.tap.fill"
            }
        }

        var stepLabel: String {
            "\(rawValue + 1) of \(Step.allCases.count)"
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
        currentStep = .tapFAB
        UserDefaults.standard.set(0, forKey: Self.stepKey)

        Task {
            try? await Task.sleep(for: .seconds(initialDelay))
            showPopover = true
        }
    }

    // MARK: - Step Completion

    /// Call when the user performs the action for the current step.
    public func completeCurrentStep() {
        guard let step = currentStep else { return }
        showPopover = false

        let nextRaw = step.rawValue + 1
        if let next = Step(rawValue: nextRaw) {
            UserDefaults.standard.set(nextRaw, forKey: Self.stepKey)
            currentStep = next
            Task {
                try? await Task.sleep(for: .seconds(interStepDelay))
                showPopover = true
            }
        } else {
            markComplete()
        }
    }

    /// Skip the entire onboarding.
    public func skip() {
        showPopover = false
        markComplete()
    }

    /// Reset onboarding (for Settings).
    public func reset() {
        UserDefaults.standard.removeObject(forKey: Self.completedKey)
        UserDefaults.standard.removeObject(forKey: Self.stepKey)
        currentStep = nil
        showPopover = false
    }

    private func markComplete() {
        currentStep = nil
        isCompleted = true
        UserDefaults.standard.removeObject(forKey: Self.stepKey)
    }
}
