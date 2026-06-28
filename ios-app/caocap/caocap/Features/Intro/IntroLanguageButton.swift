import SwiftUI

/// Compact language picker for the first-launch intro, writing to the same
/// `app_language` preference used by Settings and the app root locale.
struct IntroLanguageButton: View {
    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    let usesLightChrome: Bool

    var body: some View {
        Menu {
            ForEach(LocalizationManager.supportedLanguages, id: \.self) { language in
                Button {
                    selectedLanguage = language
                } label: {
                    if selectedLanguage == language {
                        Label(
                            LocalizationManager.shared.localizedString(language, language: language),
                            systemImage: "checkmark"
                        )
                    } else {
                        Text(LocalizationManager.shared.localizedString(language, language: language))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))
                Text(languageAbbreviation)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(labelForeground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(labelBackground, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(labelStroke, lineWidth: usesLightChrome ? 0 : 1)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizationManager.shared.localizedString("Language"))
    }

    private var languageAbbreviation: String {
        selectedLanguage == "Arabic" ? "AR" : "EN"
    }

    private var labelForeground: Color {
        usesLightChrome ? .white.opacity(0.9) : .secondary
    }

    private var labelBackground: some ShapeStyle {
        if usesLightChrome {
            return AnyShapeStyle(Color.black.opacity(0.18))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private var labelStroke: Color {
        usesLightChrome ? .clear : Color.primary.opacity(0.06)
    }
}
