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
            title: "Start the Mission",
            message: "Tap this button to open the command palette. Your first mission is Make It Remember.",
            icon: "hand.tap"
        ),
        OnboardingStepContent(
            step: .typeCoCaptainPrompt,
            title: "Ask CoCaptain",
            message: "Type \"help me make the button remember taps\" to ask your AI mentor for mission help.",
            icon: "keyboard"
        ),
        OnboardingStepContent(
            step: .submitCoCaptainPrompt,
            title: "Send to CoCaptain",
            message: "Tap the Ask CoCaptain row or press return. CoCaptain should explain the next change before you apply it.",
            icon: "sparkles"
        ),
        OnboardingStepContent(
            step: .chatCoCaptain,
            title: "Meet Your CoCaptain",
            message: "CoCaptain is your AI mentor. Ask it to help you understand state while keeping code edits ready for review.",
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
