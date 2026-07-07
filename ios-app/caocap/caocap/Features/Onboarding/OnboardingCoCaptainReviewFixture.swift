import Foundation

/// Offline-safe review bundle used when the guided onboarding edit cannot reach the model.
enum OnboardingCoCaptainReviewFixture {
    static func makeBundle(
        nodeID: UUID,
        baseText: String
    ) -> ReviewBundleItem {
        let updatedText = baseText.replacingOccurrences(
            of: "Hello World!",
            with: "Hello from CoCaptain!"
        )
        return ReviewBundleItem(
            items: [
                PendingReviewItem(
                    targetNodeID: nodeID,
                    targetLabel: "Hello World CODE",
                    summary: LocalizationManager.shared.localizedString(
                        "Update the headline to greet you from CoCaptain."
                    ),
                    preview: updatedText,
                    source: .nodeEdit(
                        role: .miniApp,
                        section: .code,
                        operations: [NodePatchOperation(type: .replaceAll, content: updatedText)],
                        baseText: baseText
                    )
                )
            ]
        )
    }
}
