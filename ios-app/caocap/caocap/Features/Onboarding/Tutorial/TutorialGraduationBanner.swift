import SwiftUI

/// Short celebration copy shown with confetti when the interactive tutorial completes.
struct TutorialGraduationBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(LocalizationManager.shared.localizedString("onboarding.tutorialGraduation.title"))
                    .font(.headline)
            } icon: {
                Image(systemName: "party.popper.fill")
            }

            Text(LocalizationManager.shared.localizedString("onboarding.tutorialGraduation.message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
