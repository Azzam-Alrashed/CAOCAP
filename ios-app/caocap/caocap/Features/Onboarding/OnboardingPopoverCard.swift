import SwiftUI

/// A shape that outlines a rounded rectangle bubble with a triangle arrow pointing down or up.
struct UnifiedBubbleWithArrowShape: Shape {
    enum ArrowPlacement {
        case top, bottom
    }
    
    var cornerRadius: CGFloat = 16
    var arrowSize: CGSize = CGSize(width: 16, height: 8)
    var arrowOffset: CGFloat = 0 // Offset from center
    var placement: ArrowPlacement = .bottom
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let bubbleHeight = rect.height - arrowSize.height
        let minX = rect.minX
        let maxX = rect.maxX
        
        let minY = placement == .top ? rect.minY + arrowSize.height : rect.minY
        let maxY = placement == .top ? rect.maxY : rect.minY + bubbleHeight
        
        // Calculate arrow center and clamp to keep it within bubble bounds
        let baseMidX = rect.midX + arrowOffset
        let minArrowX = minX + cornerRadius + arrowSize.width / 2
        let maxArrowX = maxX - cornerRadius - arrowSize.width / 2
        let midX = min(max(baseMidX, minArrowX), maxArrowX)
        
        // Start at top-left corner (after the radius)
        path.move(to: CGPoint(x: minX + cornerRadius, y: minY))
        
        // If arrow is at the top, draw it pointing up
        if placement == .top {
            path.addLine(to: CGPoint(x: midX - arrowSize.width / 2, y: minY))
            path.addLine(to: CGPoint(x: midX, y: rect.minY))
            path.addLine(to: CGPoint(x: midX + arrowSize.width / 2, y: minY))
        }
        
        // Top edge
        path.addLine(to: CGPoint(x: maxX - cornerRadius, y: minY))
        
        // Top-right corner
        path.addArc(
            center: CGPoint(x: maxX - cornerRadius, y: minY + cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )
        
        // Right edge
        path.addLine(to: CGPoint(x: maxX, y: maxY - cornerRadius))
        
        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: maxX - cornerRadius, y: maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        // If arrow is at the bottom, draw it pointing down
        if placement == .bottom {
            path.addLine(to: CGPoint(x: midX + arrowSize.width / 2, y: maxY))
            path.addLine(to: CGPoint(x: midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: midX - arrowSize.width / 2, y: maxY))
        }
        
        // Bottom edge (left of bottom arrow)
        path.addLine(to: CGPoint(x: minX + cornerRadius, y: maxY))
        
        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: minX + cornerRadius, y: maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: minX, y: minY + cornerRadius))
        
        // Top-left corner
        path.addArc(
            center: CGPoint(x: minX + cornerRadius, y: minY + cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}

/// A premium glassmorphic popover card used for onboarding tooltips.
/// Matches CAOCAP's dark, material-blurred visual language.
struct OnboardingPopoverCard: View {
    let step: OnboardingCoordinator.Step
    var isSubStep2_1: Bool = false
    var arrowOffset: CGFloat = 0
    var arrowPlacement: UnifiedBubbleWithArrowShape.ArrowPlacement = .bottom
    let onSkip: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // Gradient accent colors
    private let accentGradient = LinearGradient(
        colors: [Color(hex: "6C5CE7"), Color(hex: "0984E3")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var cardTitle: String {
        isSubStep2_1 ? "Ask CoCaptain" : step.title
    }
    
    private var cardIcon: String {
        isSubStep2_1 ? "sparkles" : step.icon
    }
    
    private var cardStepLabel: String {
        step.stepLabel
    }
    
    private var cardMessage: String {
        isSubStep2_1 ? "Tap the 'Ask CoCaptain' action row or tap the return button on your keyboard to send your message." : step.message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: icon + title + step counter
            HStack(spacing: 10) {
                // Animated icon
                Image(systemName: cardIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentGradient)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(cardTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    Text(cardStepLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Skip button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onSkip()
                    }
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }

            // Message body
            Text(cardMessage)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, arrowPlacement == .top ? 18 + 8 : 18)
        .padding(.bottom, arrowPlacement == .bottom ? 18 + 8 : 18)
        .frame(width: 290)
        .background(
            UnifiedBubbleWithArrowShape(arrowOffset: arrowOffset, placement: arrowPlacement)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            UnifiedBubbleWithArrowShape(arrowOffset: arrowOffset, placement: arrowPlacement)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.25 : 0.45),
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.15),
                            Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        .shadow(color: Color.blue.opacity(0.08), radius: 30, x: 0, y: 5)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
            ForEach(OnboardingCoordinator.Step.allCases, id: \.rawValue) { step in
                OnboardingPopoverCard(step: step, onSkip: {})
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
