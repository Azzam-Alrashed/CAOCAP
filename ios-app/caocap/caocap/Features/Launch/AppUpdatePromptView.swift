import SwiftUI

struct AppUpdatePromptView: View {
    let update: AppUpdateInfo
    let onUpdate: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 84, height: 84)

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 46, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 8) {
                        Text("Update Required")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("This version of CAOCAP is no longer supported. Update to version \(update.minimumRequiredVersion) or newer to continue.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    openURL(update.appStoreURL)
                    onUpdate()
                } label: {
                    Label("Update Now", systemImage: "arrow.up.forward")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.32))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    AppUpdatePromptView(
        update: AppUpdateInfo(
            currentVersion: "7.2.0",
            minimumRequiredVersion: "7.3.0",
            appStoreURL: URL(string: "https://apps.apple.com")!
        ),
        onUpdate: {}
    )
    .background(Color.black)
}
