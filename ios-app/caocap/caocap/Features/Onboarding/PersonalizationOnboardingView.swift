import SwiftUI

/// Full-screen personalization flow shown after the motivational intro.
struct PersonalizationOnboardingView: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let onBackToIntro: () -> Void
    let onFinish: () -> Void

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PersonalizationSceneView(
            coordinator: coordinator,
            selectedLanguage: selectedLanguage,
            reduceMotion: reduceMotion,
            onBackToIntro: onBackToIntro,
            onContinue: {
                coordinator.next()
            },
            onFinish: onFinish
        )
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, LocalizationManager.shared.locale(for: selectedLanguage))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            coordinator.onAppearIfNeeded()
        }
        .confirmationDialog(
            LocalizedStringKey("Continue without personalizing?"),
            isPresented: $coordinator.showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("Skip anyway"), role: .destructive) {
                coordinator.confirmSkip()
                onFinish()
            }
            Button(LocalizedStringKey("Go back"), role: .cancel) {
                coordinator.cancelSkip()
            }
        } message: {
            Text(LocalizedStringKey("Personalization helps us tailor your journey."))
        }
    }
}

#Preview {
    PersonalizationOnboardingView(
        coordinator: PersonalizationOnboardingCoordinator(),
        onBackToIntro: {},
        onFinish: {}
    )
}
