import Foundation

/// Content data for a single onboarding step shown inside `OnboardingPopoverCard`.
struct OnboardingStepContent: Equatable {
    /// The onboarding step this content belongs to; used for lookup in `OnboardingManifest`.
    let step: OnboardingCoordinator.Step
    /// Short headline shown in bold at the top of the popover card.
    let title: String
    /// Descriptive body copy explaining what the user should do on this step.
    let message: String
    /// SF Symbol name for the step icon displayed in the card header.
    let icon: String
}

/// Static registry of all first-run onboarding steps.
/// Each step has its content defined here; `OnboardingCoordinator` drives the sequence.
/// To add a new step: add the case to `OnboardingCoordinator.Step`, add the content here,
/// and handle the new anchor in `OnboardingPopoverCard`.
enum OnboardingManifest {
    static let steps: [OnboardingStepContent] = [
        OnboardingStepContent(
            step: .tapFAB,
            title: "Your Command Center",
            message: "Tap this button to open the command palette, your gateway to every action in CAOCAP.",
            icon: "hand.tap"
        ),
        OnboardingStepContent(
            step: .typeCoCaptainPrompt,
            title: "Ask CoCaptain",
            message: "Type a message like \"hi\" here to turn the command palette into an AI prompt.",
            icon: "keyboard"
        ),
        OnboardingStepContent(
            step: .submitCoCaptainPrompt,
            title: "Send to CoCaptain",
            message: "Tap the Ask CoCaptain row or press return to send your message.",
            icon: "sparkles"
        ),
        OnboardingStepContent(
            step: .chatCoCaptain,
            title: "Meet Your CoCaptain",
            message: "CoCaptain is here. Type a message here to build, refine, or explain code.",
            icon: "bubble.left.and.text.bubble.right"
        ),
        OnboardingStepContent(
            step: .dismissCoCaptain,
            title: "Back to Canvas",
            message: "Tap Done or drag the panel down.",
            icon: "arrow.down"
        ),
        OnboardingStepContent(
            step: .longPressFAB,
            title: "Quick Shortcuts",
            message: "Press and hold this button to reveal quick actions. Use it to undo/redo and quickly summon CoCaptain.",
            icon: "hand.tap.fill"
        )
    ]

    /// The step to show first; `nil` if the steps array is somehow empty.
    static var firstStep: OnboardingCoordinator.Step? {
        steps.first?.step
    }

    /// Returns the content for a given step. Crashes with a `preconditionFailure` if
    /// the manifest is missing a step entry, which would indicate a programming error.
    static func content(for step: OnboardingCoordinator.Step) -> OnboardingStepContent {
        guard let content = steps.first(where: { $0.step == step }) else {
            preconditionFailure("Missing onboarding manifest content for \(step)")
        }
        return content
    }

    /// Returns the next step after the given one, or `nil` if `step` is the last.
    static func nextStep(after step: OnboardingCoordinator.Step) -> OnboardingCoordinator.Step? {
        guard let index = steps.firstIndex(where: { $0.step == step }) else { return nil }
        let nextIndex = steps.index(after: index)
        guard steps.indices.contains(nextIndex) else { return nil }
        return steps[nextIndex].step
    }

    /// Human-readable progress label such as "3 of 6" used for accessibility and the progress bar.
    static func stepLabel(for step: OnboardingCoordinator.Step) -> String {
        guard let index = steps.firstIndex(where: { $0.step == step }) else {
            return ""
        }
        return "\(index + 1) of \(steps.count)"
    }
}
