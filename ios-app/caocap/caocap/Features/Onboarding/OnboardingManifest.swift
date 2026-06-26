import Foundation

struct OnboardingStepContent: Equatable {
    let step: OnboardingCoordinator.Step
    let title: String
    let message: String
    let icon: String
}

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

    static var firstStep: OnboardingCoordinator.Step? {
        steps.first?.step
    }

    static func content(for step: OnboardingCoordinator.Step) -> OnboardingStepContent {
        guard let content = steps.first(where: { $0.step == step }) else {
            preconditionFailure("Missing onboarding manifest content for \(step)")
        }
        return content
    }

    static func nextStep(after step: OnboardingCoordinator.Step) -> OnboardingCoordinator.Step? {
        guard let index = steps.firstIndex(where: { $0.step == step }) else { return nil }
        let nextIndex = steps.index(after: index)
        guard steps.indices.contains(nextIndex) else { return nil }
        return steps[nextIndex].step
    }

    static func stepLabel(for step: OnboardingCoordinator.Step) -> String {
        guard let index = steps.firstIndex(where: { $0.step == step }) else {
            return ""
        }
        return "\(index + 1) of \(steps.count)"
    }
}
