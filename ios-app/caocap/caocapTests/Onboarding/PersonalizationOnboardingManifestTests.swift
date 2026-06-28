import Foundation
import Testing
@testable import caocap

struct PersonalizationOnboardingManifestTests {
    @Test func manifestDefinesFiveUniqueQuestions() {
        #expect(PersonalizationOnboardingManifest.questions.count == 5)

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

    @Test func stepLabelsFollowQuestionCount() {
        #expect(
            PersonalizationOnboardingManifest.stepLabel(for: 0, language: "English")
                == "Question 1 of 5"
        )
        #expect(
            PersonalizationOnboardingManifest.stepLabel(for: 4, language: "English")
                == "Question 5 of 5"
        )
        #expect(PersonalizationOnboardingManifest.lastIndex == 4)
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
    }
}
