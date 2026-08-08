import Foundation

/// Content data for a single onboarding step shown inside `OnboardingPopoverCard`.
struct OnboardingStepContent: Equatable {
    let step: OnboardingCoordinator.Step
    let titleKey: String
    let messageKey: String
    let icon: String
}

/// Static registry of all first-run onboarding steps.
enum OnboardingManifest {
    static let steps: [OnboardingStepContent] = OnboardingCoordinator.Step.allCases.map { step in
        switch step {
        case .openPortal:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.openPortal.title",
                messageKey: "onboarding.openPortal.message",
                icon: "arrow.right.circle.fill"
            )
        }
    }

    static func content(for step: OnboardingCoordinator.Step) -> OnboardingStepContent {
        guard let content = steps.first(where: { $0.step == step }) else {
            preconditionFailure("Missing onboarding manifest content for \(step)")
        }
        return content
    }
}
