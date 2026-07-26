import Foundation

/// Offline-safe typed review draft used when the guided onboarding edit cannot reach the model.
enum OnboardingCoCaptainReviewFixture {
    static func makeDraft(
        nodeID: UUID,
        baseText: String
    ) -> CoCaptainReviewLifecycle.Draft {
        let updatedText = baseText.replacingOccurrences(
            of: "Hello World!",
            with: "Hello from CoCaptain!"
        )
        return CoCaptainReviewLifecycle.Draft(
            nodeEdits: [
                CoCaptainNodeEditProposal(
                    nodeID: nodeID,
                    role: .miniApp,
                    section: .code,
                    summary: LocalizationManager.shared.localizedString(
                        "Update the headline to greet you from CoCaptain."
                    ),
                    operations: [
                        NodePatchOperation(type: .replaceAll, content: updatedText)
                    ]
                )
            ]
        )
    }
}
