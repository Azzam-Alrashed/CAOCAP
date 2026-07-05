import Foundation
import Testing
@testable import caocap

struct PersonalizationOnboardingManifestTests {
    @Test func manifestDefinesSixStepsWithCopilotFirst() {
        #expect(PersonalizationOnboardingManifest.steps.count == 6)
        #expect(PersonalizationOnboardingManifest.questions.count == 5)

        #expect(PersonalizationOnboardingManifest.isCopilotPickerStep(at: 0))

        let questionIDs = PersonalizationOnboardingManifest.questions.map(\.id)
        #expect(Set(questionIDs).count == 5)

        for question in PersonalizationOnboardingManifest.questions {
            #expect(!question.titleKey.isEmpty)
            #expect(!question.subtitleKey.isEmpty)
            #expect(!question.options.isEmpty)

            let optionIDs = question.options.map(\.id)
            #expect(Set(optionIDs).count == optionIDs.count)

            for option in question.options {
                #expect(!option.titleKey.isEmpty)
            }
        }
    }

    @Test func stepLabelsFollowTotalStepCount() {
        #expect(
            PersonalizationOnboardingManifest.stepLabel(for: 0, language: "English")
                == "Step 1 of 6"
        )
        #expect(
            PersonalizationOnboardingManifest.stepLabel(for: 5, language: "English")
                == "Step 6 of 6"
        )
        #expect(PersonalizationOnboardingManifest.lastIndex == 5)
    }

    @Test func catalogResolvesArabicPersonalizationCopy() {
        let title = LocalizationManager.shared.localizedString(
            "personalization.coding_level.title",
            language: "Arabic"
        )
        #expect(title == "ما مستوى خبرتك في البرمجة؟")

        let option = LocalizationManager.shared.localizedString(
            "personalization.coding_level.complete_beginner",
            language: "Arabic"
        )
        #expect(option == "مبتدئ تماماً")

        let copilotTitle = LocalizationManager.shared.localizedString(
            "personalization.copilot.title",
            language: "English"
        )
        #expect(copilotTitle == "Choose your co-pilot")
    }
}
