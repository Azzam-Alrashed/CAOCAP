import Foundation

/// Offline fallback used when a guided onboarding turn cannot reach the model.
/// Lesson catalogue is empty, so this no longer stages HTML review drafts.
enum OnboardingCoCaptainReviewFixture {
    static func makeDraft(
        nodeID: UUID,
        baseText: String
    ) -> CoCaptainReviewLifecycle.Draft {
        _ = nodeID
        _ = baseText
        return CoCaptainReviewLifecycle.Draft()
    }
}
