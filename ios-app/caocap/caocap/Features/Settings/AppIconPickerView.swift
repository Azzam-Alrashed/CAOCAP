import SwiftUI

/// Alternate home-screen icon picker presented from the root App Icon node.
struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = AppIconService.currentSelectionID
    @State private var applyingOptionID: String?
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var selectedOption: AppIconOption? {
        AppIconService.options.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                Circle()
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 360, height: 360)
                    .blur(radius: 70)
                    .offset(x: 120, y: -240)

                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -140, y: 320)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header

                        if let selectedOption {
                            currentIconHero(selectedOption)
                        }

                        if !AppIconService.supportsAlternateIcons {
                            unsupportedCard
                        } else {
                            iconPickerCard
                        }

                        if let errorMessage {
                            errorBanner(errorMessage)
                        }

                        footnote
                    }
                    .padding(20)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Home Screen Icon")
                .font(.system(size: 28, weight: .black, design: .rounded))
            Text("Pick how CAOCAP appears on your device. Your choice stays after relaunch.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func currentIconHero(_ option: AppIconOption) -> some View {
        VStack(spacing: 14) {
            AppIconPreviewImage(imageName: option.previewImageName, size: 96)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

            VStack(spacing: 4) {
                Text(option.displayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(option.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.indigo.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selectedID)
    }

    private var iconPickerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Icons")
                .font(.system(size: 17, weight: .bold, design: .rounded))

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(AppIconService.options) { option in
                    iconCell(option)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var unsupportedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Not Available", systemImage: "iphone.slash")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text("Alternate icons are not supported on this device.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footnote: some View {
        Text("iOS may ask you to confirm before updating the home screen icon.")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func iconCell(_ option: AppIconOption) -> some View {
        let isSelected = selectedID == option.id
        let isApplying = applyingOptionID == option.id

        Button {
            Task { await select(option) }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    AppIconPreviewImage(imageName: option.previewImageName, size: 68)
                        .opacity(isApplying ? 0.55 : 1)
                        .overlay {
                            if isApplying {
                                ProgressView()
                                    .controlSize(.regular)
                            }
                        }

                    if isSelected && !isApplying {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.indigo)
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                            Spacer()
                        }
                        .frame(width: 68, height: 68)
                        .offset(x: 8, y: -8)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.indigo : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                        .frame(width: 68, height: 68)
                }
                .shadow(color: isSelected ? Color.indigo.opacity(0.25) : .clear, radius: 10, y: 4)

                VStack(spacing: 2) {
                    Text(option.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppIconCellButtonStyle(isSelected: isSelected))
        .disabled(applyingOptionID != nil || !AppIconService.supportsAlternateIcons)
        .accessibilityLabel(option.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func select(_ option: AppIconOption) async {
        guard option.id != selectedID else { return }
        applyingOptionID = option.id
        errorMessage = nil

        do {
            try await AppIconService.setIcon(option)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selectedID = option.id
            }
            HapticsManager.shared.selectionChanged()
            HapticsManager.shared.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticsManager.shared.notification(.error)
        }

        applyingOptionID = nil
    }
}

private struct AppIconPreviewImage: View {
    let imageName: String
    let size: CGFloat

    var body: some View {
        Image(imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
    }
}

private struct AppIconCellButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : (isSelected ? 1.02 : 1))
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
