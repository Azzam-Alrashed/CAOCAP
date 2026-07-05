import SwiftUI

/// Header and selected co-pilot info card for step 1 (no hero layout).
struct PersonalizationCopilotStepContent: View {
    let content: CopilotPickerContent
    @Bindable var coordinator: PersonalizationOnboardingCoordinator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 4)

            selectedInfoCard
                .padding(.top, isCompactHeight ? 12 : 16)

            Spacer(minLength: 0)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedInfoCard: some View {
        CopilotPickerCard(
            persona: coordinator.selectedCopilot,
            isSelected: true
        ) {
            coordinator.selectCopilot(coordinator.selectedCopilot)
        }
        .frame(maxWidth: 320)
        .allowsHitTesting(false)
        .id(coordinator.selectedCopilot)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74), value: coordinator.selectedCopilot)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 8 : 10) {
            Text(LocalizedStringKey(stringLiteral: content.titleKey))
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .foregroundStyle(PersonalizationTheme.textPrimary)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalizedStringKey(stringLiteral: content.subtitleKey))
                .font(.system(size: isCompactHeight ? 15 : 16, weight: .medium))
                .foregroundStyle(PersonalizationTheme.textSecondary)
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
