import Foundation

/// Content data for a single onboarding step shown inside `OnboardingPopoverCard`.
struct OnboardingStepContent: Equatable {
    /// The onboarding step this content belongs to; used for lookup in `OnboardingManifest`.
    let step: OnboardingCoordinator.Step
    /// Catalog key for the short headline shown in bold at the top of the popover card.
    let titleKey: String
    /// Catalog key for the descriptive body copy explaining what the user should do on this step.
    let messageKey: String
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
            step: .openTutorial,
            titleKey: "onboarding.openTutorial.title",
            messageKey: "onboarding.openTutorial.message",
            icon: "graduationcap.fill"
        ),
        OnboardingStepContent(
            step: .tapFAB,
            titleKey: "onboarding.tapFAB.title",
            messageKey: "onboarding.tapFAB.message",
            icon: "hand.tap"
        ),
        OnboardingStepContent(
            step: .typeCoCaptainPrompt,
            titleKey: "onboarding.typeCoCaptainPrompt.title",
            messageKey: "onboarding.typeCoCaptainPrompt.message",
            icon: "keyboard"
        ),
        OnboardingStepContent(
            step: .submitCoCaptainPrompt,
            titleKey: "onboarding.submitCoCaptainPrompt.title",
            messageKey: "onboarding.submitCoCaptainPrompt.message",
            icon: "sparkles"
        ),
        OnboardingStepContent(
            step: .chatCoCaptain,
            titleKey: "onboarding.chatCoCaptain.title",
            messageKey: "onboarding.chatCoCaptain.message",
            icon: "bubble.left.and.text.bubble.right"
        ),
        OnboardingStepContent(
            step: .dismissCoCaptain,
            titleKey: "onboarding.dismissCoCaptain.title",
            messageKey: "onboarding.dismissCoCaptain.message",
            icon: "arrow.down"
        ),
        OnboardingStepContent(
            step: .longPressFAB,
            titleKey: "onboarding.longPressFAB.title",
            messageKey: "onboarding.longPressFAB.message",
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

    /// Human-readable progress label such as "3 of 7" used for accessibility and the progress bar.
    static func stepLabel(for step: OnboardingCoordinator.Step, language: String? = nil) -> String {
        guard let index = steps.firstIndex(where: { $0.step == step }) else {
            return ""
        }
        return LocalizationManager.shared.localizedString(
            "onboarding.canvas.stepLabel",
            arguments: [index + 1, steps.count],
            language: language
        )
    }
}
