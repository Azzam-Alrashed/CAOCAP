import Observation
import SwiftUI

enum PersonalizationLaunchPhase: Equatable {
    case idle
    case ignition
    case buildup
    case liftoff
    case wipe
    case completed
}

protocol PersonalizationLaunchTiming: Sendable {
    func wait(for duration: Duration) async
}

struct ContinuousPersonalizationLaunchTiming: PersonalizationLaunchTiming {
    func wait(for duration: Duration) async {
        try? await Task.sleep(for: duration)
    }
}

@MainActor
@Observable
final class PersonalizationLaunchController {
    private(set) var phase: PersonalizationLaunchPhase = .idle
    private(set) var titleOpacity = 1.0
    private(set) var rocketShakeOffset: CGFloat = 0
    private(set) var rocketVerticalOffset: CGFloat = 0

    var isLaunching: Bool {
        phase != .idle && phase != .completed
    }

    @ObservationIgnored
    private let timing: any PersonalizationLaunchTiming

    @ObservationIgnored
    private var launchTask: Task<Void, Never>?

    init(timing: any PersonalizationLaunchTiming = ContinuousPersonalizationLaunchTiming()) {
        self.timing = timing
    }

    func start(
        travelDistance: CGFloat,
        reduceMotion: Bool,
        audio: PersonalizationLaunchAudioPlayer,
        onComplete: @escaping @MainActor () -> Void
    ) {
        guard phase == .idle else { return }

        if reduceMotion {
            startReducedMotionSequence(audio: audio, onComplete: onComplete)
        } else {
            startFullSequence(
                travelDistance: travelDistance,
                audio: audio,
                onComplete: onComplete
            )
        }
    }

    func cancel(audio: PersonalizationLaunchAudioPlayer) {
        launchTask?.cancel()
        launchTask = nil
        audio.stop()
    }

    private func startFullSequence(
        travelDistance: CGFloat,
        audio: PersonalizationLaunchAudioPlayer,
        onComplete: @escaping @MainActor () -> Void
    ) {
        phase = .ignition
        HapticsManager.shared.trigger(.medium)
        audio.playIgnition()

        withAnimation(.easeOut(duration: 0.2)) {
            titleOpacity = 0
        }

        withAnimation(.linear(duration: 0.055).repeatCount(17, autoreverses: true)) {
            rocketShakeOffset = 4
        }

        launchTask = Task { @MainActor [weak self] in
            guard let self else { return }

            await timing.wait(for: .milliseconds(450))
            guard shouldContinue else { return }

            phase = .buildup

            // Let the final rocket-driven smoke burst finish, then hold the
            // fully covered scene for a short beat before the reveal.
            await timing.wait(for: .milliseconds(650))
            guard shouldContinue else { return }

            phase = .liftoff
            HapticsManager.shared.trigger(.heavy)
            audio.playWhoosh()

            withAnimation(.easeOut(duration: 0.08)) {
                rocketShakeOffset = 0
            }

            withAnimation(.timingCurve(0.42, 0, 0.82, 1, duration: 0.8)) {
                rocketVerticalOffset = -travelDistance
            }

            await timing.wait(for: .milliseconds(600))
            guard shouldContinue else { return }

            phase = .wipe

            await timing.wait(for: .milliseconds(500))
            guard shouldContinue else { return }

            phase = .completed
            audio.stop()
            launchTask = nil

            withAnimation(.easeOut(duration: 0.25)) {
                onComplete()
            }
        }
    }

    private func startReducedMotionSequence(
        audio: PersonalizationLaunchAudioPlayer,
        onComplete: @escaping @MainActor () -> Void
    ) {
        phase = .buildup
        HapticsManager.shared.trigger(.soft)
        audio.playIgnition(volume: 0.35)

        withAnimation(.easeOut(duration: 0.25)) {
            titleOpacity = 0
        }

        launchTask = Task { @MainActor [weak self] in
            guard let self else { return }

            await timing.wait(for: .milliseconds(350))
            guard shouldContinue else { return }

            phase = .wipe

            await timing.wait(for: .milliseconds(300))
            guard shouldContinue else { return }

            phase = .completed
            audio.stop()
            launchTask = nil

            withAnimation(.easeOut(duration: 0.15)) {
                onComplete()
            }
        }
    }

    private var shouldContinue: Bool {
        !Task.isCancelled && phase != .completed
    }
}
