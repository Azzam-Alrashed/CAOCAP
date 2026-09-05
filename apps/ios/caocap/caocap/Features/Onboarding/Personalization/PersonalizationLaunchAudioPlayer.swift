import AVFoundation

@MainActor
final class PersonalizationLaunchAudioPlayer {
    private var ignitionPlayer: AVAudioPlayer?
    private var whooshPlayer: AVAudioPlayer?

    init(bundle: Bundle = .main) {
        ignitionPlayer = makePlayer(
            named: "OnboardingLaunchIgnition",
            bundle: bundle
        )
        whooshPlayer = makePlayer(
            named: "OnboardingLaunchWhoosh",
            bundle: bundle
        )
    }

    func playIgnition(volume: Float = 0.55) {
        play(ignitionPlayer, volume: volume)
    }

    func playWhoosh(volume: Float = 0.68) {
        play(whooshPlayer, volume: volume)
    }

    func stop() {
        ignitionPlayer?.stop()
        whooshPlayer?.stop()
    }

    private func makePlayer(named name: String, bundle: Bundle) -> AVAudioPlayer? {
        guard let url = bundle.url(forResource: name, withExtension: "caf") else {
            return nil
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                options: [.mixWithOthers]
            )
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    private func play(_ player: AVAudioPlayer?, volume: Float) {
        guard let player else { return }
        player.stop()
        player.currentTime = 0
        player.volume = volume
        player.play()
    }
}
