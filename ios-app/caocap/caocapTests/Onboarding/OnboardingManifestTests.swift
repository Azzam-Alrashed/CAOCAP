import Testing
@testable import caocap

struct OnboardingManifestTests {
    @Test func manifestDefinesEveryCoordinatorStepOnce() {
        let manifestSteps = OnboardingManifest.steps.map(\.step)

        #expect(manifestSteps == OnboardingCoordinator.Step.allCases)
        #expect(Set(manifestSteps).count == OnboardingCoordinator.Step.allCases.count)
    }

    @Test func manifestDrivesStepLabelsAndProgression() {
        #expect(OnboardingManifest.firstStep == .tapFAB)
        #expect(OnboardingManifest.nextStep(after: .tapFAB) == .typeCoCaptainPrompt)
        #expect(OnboardingManifest.nextStep(after: .typeCoCaptainPrompt) == .submitCoCaptainPrompt)
        #expect(OnboardingManifest.nextStep(after: .submitCoCaptainPrompt) == .chatCoCaptain)
        #expect(OnboardingManifest.nextStep(after: .chatCoCaptain) == .dismissCoCaptain)
        #expect(OnboardingManifest.nextStep(after: .dismissCoCaptain) == .longPressFAB)
        #expect(OnboardingManifest.nextStep(after: .longPressFAB) == nil)

        #expect(OnboardingCoordinator.Step.tapFAB.stepLabel == "1 of 6")
        #expect(OnboardingCoordinator.Step.longPressFAB.stepLabel == "6 of 6")
    }

    @Test func manifestContentIsReadyForPopoverPresentation() {
        for step in OnboardingCoordinator.Step.allCases {
            let content = OnboardingManifest.content(for: step)

            #expect(!content.title.isEmpty)
            #expect(!content.message.isEmpty)
            #expect(!content.icon.isEmpty)
            #expect(content.step == step)
        }
    }
}
