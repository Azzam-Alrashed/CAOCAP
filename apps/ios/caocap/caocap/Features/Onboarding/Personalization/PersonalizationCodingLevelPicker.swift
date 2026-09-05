import SwiftUI
import AudioToolbox

enum PersonalizationCodingLevelScale {
    static let thumbRadius: CGFloat = 24

    static func position(
        for level: PersonalizationCodingLevel,
        width: CGFloat
    ) -> CGFloat {
        let availableWidth = max(width - (thumbRadius * 2), 0)
        let progress = CGFloat(level.rawValue)
            / CGFloat(PersonalizationCodingLevel.allCases.count - 1)
        return thumbRadius + (availableWidth * progress)
    }

    static func level(at locationX: CGFloat, trackWidth: CGFloat) -> PersonalizationCodingLevel {
        let availableWidth = max(trackWidth - (thumbRadius * 2), 1)
        let clampedX = min(max(locationX - thumbRadius, 0), availableWidth)
        let progress = clampedX / availableWidth
        let step = Int(
            (progress * CGFloat(PersonalizationCodingLevel.allCases.count - 1)).rounded()
        )
        return PersonalizationCodingLevel(rawValue: step) ?? .zero
    }

    static func adjustedLevel(
        from level: PersonalizationCodingLevel,
        by step: Int
    ) -> PersonalizationCodingLevel {
        let lastIndex = PersonalizationCodingLevel.allCases.count - 1
        let nextIndex = min(max(level.rawValue + step, 0), lastIndex)
        return PersonalizationCodingLevel(rawValue: nextIndex) ?? level
    }
}

struct PersonalizationCodingLevelPicker: View {
    let selection: PersonalizationCodingLevel
    let onSelect: (PersonalizationCodingLevel) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            Text(selection.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: selection)

            Text(selection.subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: selection)

            Spacer().frame(height: 6)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.22))
                        .frame(height: 48)

                    if selection != .zero {
                        liquidFill(
                            width: PersonalizationCodingLevelScale.position(
                                for: selection,
                                width: geometry.size.width
                            )
                        )
                        .animation(
                            .spring(response: 0.24, dampingFraction: 0.82),
                            value: selection.rawValue
                        )
                    }

                    ForEach(PersonalizationCodingLevel.allCases, id: \.rawValue) { level in
                        Circle()
                            .fill(Color.white.opacity(0.32))
                            .frame(width: 8, height: 8)
                            .position(
                                x: PersonalizationCodingLevelScale.position(
                                    for: level,
                                    width: geometry.size.width
                                ),
                                y: 24
                            )
                    }

                    Circle()
                        .fill(.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                        .position(
                            x: PersonalizationCodingLevelScale.position(
                                for: selection,
                                width: geometry.size.width
                            ),
                            y: 24
                        )
                        .animation(
                            .spring(response: 0.24, dampingFraction: 0.82),
                            value: selection.rawValue
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            select(
                                PersonalizationCodingLevelScale.level(
                                    at: value.location.x,
                                    trackWidth: geometry.size.width
                                )
                            )
                        }
                )
                .accessibilityElement()
                .accessibilityLabel(Text("Coding level"))
                .accessibilityValue(Text(selection.title))
                .accessibilityAdjustableAction(adjustSelection)
            }
            .frame(height: 48)
        }
        .padding(16)
    }

    private func liquidFill(width: CGFloat) -> some View {
        ZStack {
            Color(hex: "3B9AF5")

            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    GeometryReader { geometry in
                        ForEach(0..<3, id: \.self) { index in
                            let time = context.date.timeIntervalSinceReferenceDate
                            let duration = 3.8 + (Double(index) * 0.7)
                            let phase = (
                                (time / duration) + (Double(index) * 0.31)
                            ).truncatingRemainder(dividingBy: 1)
                            let size = bubbleSize(for: index)
                            let baseX = geometry.size.width * bubbleHorizontalPosition(for: index)
                            let drift = CGFloat(sin((time * 0.8) + Double(index))) * 2.5
                            let y = geometry.size.height + size
                                - (CGFloat(phase) * (geometry.size.height + (size * 2)))

                            Circle()
                                .fill(Color.white.opacity(0.13))
                                .overlay {
                                    Circle()
                                        .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                                }
                                .frame(width: size, height: size)
                                .position(
                                    x: min(max(baseX + drift, size), geometry.size.width - size),
                                    y: y
                                )
                        }
                    }
                }
            }
        }
        .frame(width: width, height: 48)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let step: Int

        switch direction {
        case .increment:
            step = 1
        case .decrement:
            step = -1
        @unknown default:
            return
        }

        select(PersonalizationCodingLevelScale.adjustedLevel(from: selection, by: step))
    }

    private func select(_ level: PersonalizationCodingLevel) {
        guard level != selection else { return }
        onSelect(level)
        AudioServicesPlaySystemSound(1104)
        HapticsManager.shared.selectionChanged()
    }

    private func bubbleSize(for index: Int) -> CGFloat {
        [5, 7, 4][index]
    }

    private func bubbleHorizontalPosition(for index: Int) -> CGFloat {
        [0.28, 0.58, 0.8][index]
    }
}
