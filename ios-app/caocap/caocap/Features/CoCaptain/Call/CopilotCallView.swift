import SwiftUI

/// Call chrome for Gemini Live voice and screen-share sessions.
/// Voice fills the canvas; video stays a compact bottom overlay so ReplayKit can see the canvas.
struct CopilotCallView: View {
    @Bindable var viewModel: CopilotCallViewModel

    var body: some View {
        Group {
            if viewModel.mode == .video {
                videoOverlay
            } else {
                voiceFullScreen
            }
        }
        .onAppear {
            viewModel.start()
        }
    }

    private var voiceFullScreen: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: viewModel.persona.accentHex).opacity(0.28),
                    Color.black.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .background(.ultraThinMaterial)

            VStack(spacing: 28) {
                Spacer(minLength: 40)
                avatar(size: 160)
                titleBlock
                transcriptBlock
                Spacer()
                controls
                    .padding(.bottom, 36)
            }
            .padding(.horizontal, 20)
        }
    }

    private var videoOverlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .center, spacing: 14) {
                avatar(size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text(LocalizationManager.shared.localizedString("copilot.call.recording"))
                            .font(.caption.weight(.semibold))
                    }
                    Text(viewModel.persona.displayName)
                        .font(.headline)
                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                compactControls
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .allowsHitTesting(true)
    }

    private func avatar(size: CGFloat) -> some View {
        Image(viewModel.persona.avatarImageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(hex: viewModel.persona.accentHex).opacity(0.55), lineWidth: 2)
            )
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text(viewModel.persona.displayName)
                .font(.system(size: 24, weight: .semibold))
            Text(LocalizationManager.shared.localizedString(viewModel.mode.localizedTitleKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var transcriptBlock: some View {
        if !viewModel.outputTranscript.isEmpty {
            Text(viewModel.outputTranscript)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .lineLimit(4)
        } else if !viewModel.inputTranscript.isEmpty {
            Text(viewModel.inputTranscript)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .lineLimit(3)
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            muteButton(size: 64)
            endButton(size: 72)
        }
    }

    private var compactControls: some View {
        HStack(spacing: 12) {
            muteButton(size: 44)
            endButton(size: 48)
        }
    }

    private func muteButton(size: CGFloat) -> some View {
        Button {
            viewModel.toggleMute()
        } label: {
            Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: size * 0.34, weight: .semibold))
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(
            viewModel.isMuted
                ? LocalizationManager.shared.localizedString("copilot.call.unmute")
                : LocalizationManager.shared.localizedString("copilot.call.mute")
        )
    }

    private func endButton(size: CGFloat) -> some View {
        Button {
            viewModel.endCall()
        } label: {
            Image(systemName: "phone.down.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.red, in: Circle())
        }
        .accessibilityLabel(LocalizationManager.shared.localizedString("copilot.call.end"))
    }
}
