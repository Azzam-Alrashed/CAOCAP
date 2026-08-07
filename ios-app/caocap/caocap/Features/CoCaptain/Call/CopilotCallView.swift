import SwiftUI

/// Compact, draggable call chrome for Gemini Live voice and screen-share sessions.
/// Starts at the top of the canvas and can be dragged out of the way.
struct CopilotCallView: View {
    @Bindable var viewModel: CopilotCallViewModel
    var onFrameChange: ((CGRect) -> Void)? = nil

    @State private var position: CGPoint = .zero
    @State private var dragStart: CGPoint = .zero
    @State private var isDragging = false
    @State private var appeared = false
    @State private var statusPulse = false

    static let cardSize = CGSize(width: 268, height: 64)
    private let edgePadding: CGFloat = 16

    private var cardSize: CGSize { Self.cardSize }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let currentPos = position == .zero ? defaultPosition(in: size) : position

            callCard
                .frame(width: cardSize.width, height: cardSize.height)
                .scaleEffect(isDragging ? 1.04 : (appeared ? 1 : 0.86))
                .opacity(appeared ? 1 : 0)
                .shadow(
                    color: .black.opacity(isDragging ? 0.28 : 0.16),
                    radius: isDragging ? 18 : 10,
                    y: isDragging ? 10 : 5
                )
                .position(currentPos)
                .gesture(dragGesture(in: size, currentPos: currentPos))
                .onAppear {
                    if position == .zero {
                        position = defaultPosition(in: size)
                    }
                    reportFrame(at: position == .zero ? defaultPosition(in: size) : position)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                        appeared = true
                    }
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        statusPulse = true
                    }
                    viewModel.start()
                }
                .onDisappear {
                    onFrameChange?(.null)
                }
                .onChange(of: geometry.size) { _, newSize in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        position = clamped(position, in: newSize)
                    }
                    reportFrame(at: clamped(position, in: newSize))
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.isMuted)
                .animation(.easeInOut(duration: 0.25), value: viewModel.connectionState)
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
    }

    private var callCard: some View {
        HStack(spacing: 10) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 6, height: 6)
                        .scaleEffect(statusPulse && isLive ? 1.35 : 1)
                        .opacity(statusPulse && isLive ? 1 : 0.7)

                    Text(modeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(viewModel.persona.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(viewModel.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 4)

            muteButton
            endButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: viewModel.persona.accentHex).opacity(0.22), lineWidth: 1)
        )
    }

    private var avatar: some View {
        Image(viewModel.persona.avatarImageName)
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(hex: viewModel.persona.accentHex).opacity(0.5), lineWidth: 1.5)
            )
    }

    private var muteButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                viewModel.toggleMute()
            }
        } label: {
            Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(viewModel.isMuted ? Color.orange : Color.primary)
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            viewModel.isMuted
                ? LocalizationManager.shared.localizedString("copilot.call.unmute")
                : LocalizationManager.shared.localizedString("copilot.call.mute")
        )
    }

    private var endButton: some View {
        Button {
            viewModel.endCall()
        } label: {
            Image(systemName: "phone.down.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.red, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizationManager.shared.localizedString("copilot.call.end"))
    }

    private var modeLabel: String {
        LocalizationManager.shared.localizedString(
            viewModel.mode == .video
                ? "copilot.call.recording"
                : viewModel.mode.localizedTitleKey
        )
    }

    private var statusDotColor: Color {
        switch viewModel.connectionState {
        case .connected:
            return viewModel.mode == .video ? .red : Color(hex: viewModel.persona.accentHex)
        case .connecting:
            return .orange
        case .failed:
            return .red
        case .ended, .idle:
            return .secondary
        }
    }

    private var isLive: Bool {
        if case .connected = viewModel.connectionState { return true }
        if case .connecting = viewModel.connectionState { return true }
        return false
    }

    private func dragGesture(in size: CGSize, currentPos: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isDragging {
                    dragStart = currentPos
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isDragging = true
                    }
                }
                let next = clamped(
                    CGPoint(
                        x: dragStart.x + value.translation.width,
                        y: dragStart.y + value.translation.height
                    ),
                    in: size
                )
                position = next
                reportFrame(at: next)
            }
            .onEnded { _ in
                let snapped = softSnap(position, in: size)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    isDragging = false
                    position = snapped
                }
                reportFrame(at: snapped)
            }
    }

    private func reportFrame(at center: CGPoint) {
        onFrameChange?(
            CGRect(
                x: center.x - cardSize.width / 2,
                y: center.y - cardSize.height / 2,
                width: cardSize.width,
                height: cardSize.height
            )
        )
    }

    /// Top-center, clear of the bottom-trailing FAB.
    private func defaultPosition(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2,
            y: edgePadding + cardSize.height / 2 + 54
        )
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let minX = edgePadding + cardSize.width / 2
        let maxX = size.width - edgePadding - cardSize.width / 2
        let minY = edgePadding + cardSize.height / 2 + 44
        let maxY = size.height - edgePadding - cardSize.height / 2
        return CGPoint(
            x: min(max(point.x, minX), max(minX, maxX)),
            y: min(max(point.y, minY), max(minY, maxY))
        )
    }

    private func softSnap(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let clampedPoint = clamped(point, in: size)
        let midX = size.width / 2
        let snapThreshold: CGFloat = 36
        var x = clampedPoint.x
        if abs(x - midX) < snapThreshold {
            x = midX
        } else if x < midX * 0.45 {
            x = edgePadding + cardSize.width / 2
        } else if x > midX * 1.55 {
            x = size.width - edgePadding - cardSize.width / 2
        }
        return CGPoint(x: x, y: clampedPoint.y)
    }
}
