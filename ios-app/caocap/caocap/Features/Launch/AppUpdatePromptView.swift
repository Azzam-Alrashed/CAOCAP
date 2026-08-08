import SwiftUI

/// A blocking full-bleed overlay when the running app version is below
/// `AppUpdateInfo.minimumRequiredVersion`. The only action is Update Now,
/// which opens the App Store and calls `onUpdate`.
struct AppUpdatePromptView: View {
    let update: AppUpdateInfo
    let onUpdate: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 18
    @State private var glowOpacity: Double = 0
    @State private var backgroundScale: CGFloat = 1.04

    var body: some View {
        ZStack {
            atmosphere

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 28) {
                    brandMark

                    VStack(spacing: 12) {
                        Text("Update Required")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(messageText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    versionPath
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 0)

                Button {
                    openURL(update.appStoreURL)
                    onUpdate()
                } label: {
                    Text("Update Now")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .onAppear(perform: playEntrance)
    }

    private var atmosphere: some View {
        ZStack {
            Color(hex: "050505")
                .ignoresSafeArea()

            GeometryReader { geometry in
                Image("SpaceSketchBG")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .scaleEffect(backgroundScale)
            }
            .ignoresSafeArea()
            .opacity(0.34)
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color(hex: "3B82F6").opacity(0.22),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 340
            )
            .opacity(glowOpacity)
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var brandMark: some View {
        Text("CAOCAP")
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .tracking(2)
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Color(hex: "E2E8F0")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var versionPath: some View {
        HStack(spacing: 10) {
            versionChip(update.currentVersion, emphasized: false)
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
            versionChip(update.minimumRequiredVersion, emphasized: true)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Version \(update.currentVersion) to \(update.minimumRequiredVersion)"
        )
    }

    private func versionChip(_ version: String, emphasized: Bool) -> some View {
        Text(version)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(emphasized ? .white : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(emphasized ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(emphasized ? 0.22 : 0.1), lineWidth: 1)
            )
    }

    private var messageText: String {
        String(
            format: String(
                localized: "This version of CAOCAP is no longer supported. Update to version %@ or newer to continue."
            ),
            update.minimumRequiredVersion
        )
    }

    private func playEntrance() {
        if reduceMotion {
            contentOpacity = 1
            contentOffset = 0
            glowOpacity = 1
            backgroundScale = 1
            return
        }

        withAnimation(.easeOut(duration: 0.55)) {
            contentOpacity = 1
            contentOffset = 0
        }
        withAnimation(.easeIn(duration: 1.1).delay(0.15)) {
            glowOpacity = 1
        }
        withAnimation(.easeOut(duration: 8).delay(0.2)) {
            backgroundScale = 1
        }
    }
}

#Preview {
    AppUpdatePromptView(
        update: AppUpdateInfo(
            currentVersion: "9.0.0",
            minimumRequiredVersion: "9.0.1",
            appStoreURL: URL(string: "https://apps.apple.com")!
        ),
        onUpdate: {}
    )
}
