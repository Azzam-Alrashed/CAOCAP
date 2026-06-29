import SwiftUI

/// Alternate home-screen icon picker presented from the root App Icon node.
struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = AppIconService.currentSelectionID
    @State private var isApplying = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Icon")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                        Text("Choose how CAOCAP appears on your home screen.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if !AppIconService.supportsAlternateIcons {
                        Text("Alternate icons are not supported on this device.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(AppIconService.options) { option in
                                iconCell(option)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func iconCell(_ option: AppIconOption) -> some View {
        Button {
            Task { await select(option) }
        } label: {
            VStack(spacing: 8) {
                Image(option.previewImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedID == option.id ? Color.accentColor : Color.clear,
                                lineWidth: 3
                            )
                    }

                Text(option.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(isApplying || !AppIconService.supportsAlternateIcons)
    }

    private func select(_ option: AppIconOption) async {
        guard option.id != selectedID else { return }
        isApplying = true
        errorMessage = nil
        defer { isApplying = false }

        do {
            try await AppIconService.setIcon(option)
            selectedID = option.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
