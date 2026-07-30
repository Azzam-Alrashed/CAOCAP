import SwiftUI

/// Temporary handoff screen shown while the new personalization experience is designed.
struct PersonalizationOnboardingView: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let onBackToIntro: () -> Void
    let onFinish: () -> Void

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"

    var body: some View {
        ZStack {
            Color(hex: "F7F5F2")
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color(hex: "3157D5"))
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(LocalizedStringKey("Personalization"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "17213D"))

                    Text(LocalizedStringKey("A new personalization experience is coming soon."))
                        .font(.system(size: 17))
                        .foregroundStyle(Color(hex: "58627A"))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: onBackToIntro) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 54, height: 54)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(hex: "17213D"))
                    .background(Color.white, in: Circle())
                    .accessibilityLabel(Text(LocalizedStringKey("Back")))

                    Button {
                        coordinator.complete()
                        onFinish()
                    } label: {
                        Text(LocalizedStringKey("Continue"))
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(Color(hex: "17213D"), in: Capsule())
                }
            }
            .padding(24)
        }
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, LocalizationManager.shared.locale(for: selectedLanguage))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PersonalizationOnboardingView(
        coordinator: PersonalizationOnboardingCoordinator(),
        onBackToIntro: {},
        onFinish: {}
    )
}
