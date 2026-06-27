import Foundation
import Testing
@testable import caocap

struct PersonalizationOnboardingManifestTests {
    @Test func manifestDefinesFiveUniqueQuestions() {
        #expect(PersonalizationOnboardingManifest.questions.count == 5)

        let questionIDs = PersonalizationOnboardingManifest.questions.map(\.id)
        #expect(Set(questionIDs).count == 5)

        for question in PersonalizationOnboardingManifest.questions {
            #expect(!question.title.isEmpty)
            #expect(!question.subtitle.isEmpty)
            #expect(!question.options.isEmpty)

            let optionIDs = question.options.map(\.id)
            #expect(Set(optionIDs).count == optionIDs.count)
        }
    }

    @Test func stepLabelsFollowQuestionCount() {
        #expect(PersonalizationOnboardingManifest.stepLabel(for: 0) == "Question 1 of 5")
        #expect(PersonalizationOnboardingManifest.stepLabel(for: 4) == "Question 5 of 5")
        #expect(PersonalizationOnboardingManifest.lastIndex == 4)
    }
}
