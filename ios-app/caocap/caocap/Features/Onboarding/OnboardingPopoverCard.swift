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

enum OnboardingTooltipAnchor: Hashable {
    /// Anchored to the Tutorial portal on the root canvas.
    case tutorialNode
    /// Anchored to the floating command button (FAB) at the bottom of the canvas.
    case floatingCommandButton
    /// Anchored to the omnibox search text field.
    case omniboxSearchField
    /// Anchored to the "Ask CoCaptain" prompt row inside the omnibox.
    case omniboxPromptRow
    /// Anchored to the CoCaptain chat input field.
    case coCaptainInput
    /// Anchored to the CoCaptain panel's Done/dismiss button.
    case coCaptainDoneButton
}

/// Collects layout anchors for each named onboarding target so the tooltip overlay
/// can position itself relative to any annotated view in the hierarchy.
private struct OnboardingTooltipAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [OnboardingTooltipAnchor: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [OnboardingTooltipAnchor: Anchor<CGRect>],
        nextValue: () -> [OnboardingTooltipAnchor: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Tracks the rendered size of the tooltip card so `tooltipCenter` can clamp position
/// correctly before the card is actually measured for the first time.
private struct OnboardingTooltipSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 290, height: 180)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    /// Tags a view with an onboarding anchor so the tooltip overlay knows where to point.
    func onboardingTooltipAnchor(_ anchor: OnboardingTooltipAnchor) -> some View {
        anchorPreference(key: OnboardingTooltipAnchorPreferenceKey.self, value: .bounds) {
            [anchor: $0]
        }
    }

    /// Registers the canonical Tutorial node without teaching Canvas views about
    /// the tooltip preference-key implementation.
    func tutorialOnboardingAnchor(isEnabled: Bool) -> some View {
        anchorPreference(key: OnboardingTooltipAnchorPreferenceKey.self, value: .bounds) {
            isEnabled ? [.tutorialNode: $0] : [:]
        }
    }

    /// Reads all accumulated anchors and renders the tooltip overlay in a single pass,
    /// avoiding multiple layout passes that could cause jitter.
    func onboardingTooltipOverlay() -> some View {
        overlayPreferenceValue(OnboardingTooltipAnchorPreferenceKey.self) { anchors in
            OnboardingTooltipOverlay(anchors: anchors)
        }
    }
}

extension OnboardingCoordinator.Step {
    var tooltipAnchor: OnboardingTooltipAnchor {
        switch self {
        case .openTutorial:
            return .tutorialNode
        case .tapFAB, .longPressFAB:
            return .floatingCommandButton
        case .typeCoCaptainPrompt:
            return .omniboxSearchField
        case .submitCoCaptainPrompt:
            return .omniboxPromptRow
        case .chatCoCaptain:
            return .coCaptainInput
        case .dismissCoCaptain:
            return .coCaptainDoneButton
        }
    }

    var tooltipArrowPlacement: UnifiedBubbleWithArrowShape.ArrowPlacement {
        switch self {
        case .dismissCoCaptain:
            return .top
        case .openTutorial, .tapFAB, .typeCoCaptainPrompt, .submitCoCaptainPrompt, .chatCoCaptain, .longPressFAB:
            return .bottom
        }
    }
}

/// An overlay view that reads the registered anchor frames and positions a
/// `OnboardingPopoverCard` relative to the currently active step's target.
/// The tooltip is positioned to stay within safe area margins and transitions
/// with a spring scale-plus-fade animation.
private struct OnboardingTooltipOverlay: View {
    let anchors: [OnboardingTooltipAnchor: Anchor<CGRect>]

    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    @State private var cardSize = CGSize(width: 290, height: 180)

    var body: some View {
        GeometryReader { proxy in
            if let onboarding,
               let step = onboarding.currentStep,
               onboarding.showPopover,
               let anchor = anchors[step.tooltipAnchor] {
                let targetFrame = proxy[anchor]
                let tooltipCenter = tooltipCenter(
                    for: targetFrame,
                    placement: step.tooltipArrowPlacement,
                    cardSize: cardSize,
                    containerSize: proxy.size
                )
                let arrowOffset = targetFrame.midX - tooltipCenter.x

                OnboardingPopoverCard(
                    step: step,
                    arrowOffset: arrowOffset,
                    arrowPlacement: step.tooltipArrowPlacement
                ) {
                    onboarding.skip()
                }
                .background(
                    GeometryReader { cardProxy in
                        Color.clear.preference(
                            key: OnboardingTooltipSizePreferenceKey.self,
                            value: cardProxy.size
                        )
                    }
                )
                .onPreferenceChange(OnboardingTooltipSizePreferenceKey.self) { newSize in
                    cardSize = newSize
                }
                .position(tooltipCenter)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(1000)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: onboarding?.currentStep)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: onboarding?.showPopover)
    }

    /// Computes the center point for the tooltip card, keeping it inset from screen edges
    /// and on the correct side of the target frame based on arrow placement.
    private func tooltipCenter(
        for targetFrame: CGRect,
        placement: UnifiedBubbleWithArrowShape.ArrowPlacement,
        cardSize: CGSize,
        containerSize: CGSize
    ) -> CGPoint {
        let safetyMargin: CGFloat = 16
        let spacing: CGFloat = 8
        let halfWidth = cardSize.width / 2
        let halfHeight = cardSize.height / 2

        let x = min(
            max(targetFrame.midX, safetyMargin + halfWidth),
            max(safetyMargin + halfWidth, containerSize.width - safetyMargin - halfWidth)
        )

        let unclampedY: CGFloat
        switch placement {
        case .bottom:
            unclampedY = targetFrame.minY - spacing - halfHeight
        case .top:
            unclampedY = targetFrame.maxY + spacing + halfHeight
        }

        let y = min(
            max(unclampedY, safetyMargin + halfHeight),
            max(safetyMargin + halfHeight, containerSize.height - safetyMargin - halfHeight)
        )

        return CGPoint(x: x, y: y)
    }
}

/// A premium glassmorphic popover card used for onboarding tooltips.
/// Matches CAOCAP's dark, material-blurred visual language.
struct OnboardingPopoverCard: View {
    let step: OnboardingCoordinator.Step
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: icon + title + step counter
            HStack(spacing: 10) {
                // Animated icon
                Image(systemName: step.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentGradient)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(stringLiteral: step.titleKey))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    OnboardingProgressBar(step: step)
                }

                Spacer()

                // Skip button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onSkip()
                    }
                } label: {
                    Text(LocalizedStringKey("Skip"))
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
            Text(LocalizedStringKey(stringLiteral: step.messageKey))
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

/// A step-progress bar that fills from the left as the user advances through onboarding.
/// Completed and current steps are shown in blue; future steps use a muted primary.
private struct OnboardingProgressBar: View {
    let step: OnboardingCoordinator.Step

    private var currentIndex: Int {
        OnboardingManifest.steps.firstIndex(where: { $0.step == step }) ?? 0
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(OnboardingManifest.steps.enumerated()), id: \.element.step.rawValue) { index, _ in
                Capsule()
                    .fill(index <= currentIndex ? Color.blue.opacity(0.85) : Color.primary.opacity(0.12))
                    .frame(width: 16, height: 4)
            }
        }
        .accessibilityLabel(Text(step.stepLabel))
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
