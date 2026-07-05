import SwiftUI

/// Co-pilot selection step in personalization onboarding.
struct PersonalizationCopilotPickerView: View {
    let content: CopilotPickerContent
    @Bindable var coordinator: PersonalizationOnboardingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: isCompactHeight ? 8 : 16)

            PersonalizationCopilotStage(coordinator: coordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            Text(LocalizedStringKey(stringLiteral: content.footnoteKey))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PersonalizationMoonTheme.textMuted)
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.top, isCompactHeight ? 4 : 8)
                .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 8 : 10) {
            Text(LocalizedStringKey(stringLiteral: content.titleKey))
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .foregroundStyle(PersonalizationMoonTheme.textPrimary)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalizedStringKey(stringLiteral: content.subtitleKey))
                .font(.system(size: isCompactHeight ? 15 : 16, weight: .medium))
                .foregroundStyle(PersonalizationMoonTheme.textSecondary)
                .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var titleSize: CGFloat {
        if isCompactHeight { return 26 }
        return UIDevice.current.userInterfaceIdiom == .pad ? 34 : 28
    }

    private var isCompactHeight: Bool {
        UIScreen.main.bounds.height < 700
    }
}
