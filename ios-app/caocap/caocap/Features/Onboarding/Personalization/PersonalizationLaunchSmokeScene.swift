import SpriteKit
import UIKit

@MainActor
final class PersonalizationLaunchSmokeScene: SKScene {
    private let emitter = SKEmitterNode()
    private var launchPhase: PersonalizationLaunchPhase = .idle
    private var restingEmitterHeight: CGFloat = 72

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        configureEmitter()
        configureTurbulence()
    }

    convenience override init() {
        self.init(size: CGSize(width: 1, height: 1))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        view.backgroundColor = .clear
        updateRestingEmitterPosition()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard launchPhase != .liftoff else { return }
        updateRestingEmitterPosition()
    }

    func transition(to phase: PersonalizationLaunchPhase) {
        guard phase != launchPhase else { return }
        launchPhase = phase

        switch phase {
        case .idle:
            reset()
        case .ignition:
            beginIgnition()
        case .buildup:
            emitter.particleBirthRate = 360
        case .liftoff:
            beginLiftoff()
        case .wipe:
            beginWipe()
        case .completed:
            stop()
        }
    }

    func setRestingEmitterHeight(_ height: CGFloat) {
        restingEmitterHeight = height
        guard launchPhase != .liftoff else { return }
        updateRestingEmitterPosition()
    }

    func stop() {
        emitter.removeAllActions()
        emitter.particleBirthRate = 0
        removeAllActions()
    }

    private func configureEmitter() {
        emitter.particleTexture = makeSmokeTexture()
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 1.35
        emitter.particleLifetimeRange = 0.35
        emitter.particlePositionRange = CGVector(dx: 20, dy: 8)
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi * 0.95
        emitter.particleSpeed = 48
        emitter.particleSpeedRange = 32
        emitter.particleAlpha = 0.96
        emitter.particleAlphaRange = 0.04
        emitter.particleAlphaSpeed = -0.5
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.14
        emitter.particleScaleSpeed = 0.58
        emitter.particleRotationRange = .pi
        emitter.particleRotationSpeed = 0.35
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor.white,
                UIColor(red: 0.78, green: 0.88, blue: 1, alpha: 1),
                UIColor(red: 0.82, green: 0.73, blue: 1, alpha: 1)
            ],
            times: [0, 0.55, 1]
        )
        emitter.targetNode = self
        emitter.fieldBitMask = 1
        addChild(emitter)
    }

    private func configureTurbulence() {
        let turbulence = SKFieldNode.turbulenceField(
            withSmoothness: 0.85,
            animationSpeed: 0.45
        )
        turbulence.strength = 1.35
        turbulence.falloff = 0
        turbulence.categoryBitMask = 1
        addChild(turbulence)
    }

    private func beginIgnition() {
        emitter.removeAllActions()
        updateRestingEmitterPosition()
        configureLaunchSiteExhaust()
        emitter.particleBirthRate = 70

        emitter.run(
            .customAction(withDuration: 0.55) { [weak emitter] _, elapsedTime in
                let progress = min(max(elapsedTime / 0.55, 0), 1)
                emitter?.particleBirthRate = 70 + (290 * progress)
            },
            withKey: "ignition-ramp"
        )
    }

    private func beginLiftoff() {
        emitter.removeAction(forKey: "ignition-ramp")
        emitter.particleBirthRate = 420

        let travel = SKAction.moveTo(
            y: size.height * 1.2,
            duration: 0.8
        )
        travel.timingMode = .easeIn

        emitter.run(travel, withKey: "liftoff")
    }

    private func beginWipe() {
        // The final cloud is still emitted from the rocket: by this point the
        // emitter is travelling beyond the top of the scene with its engine.
        emitter.removeAction(forKey: "screen-fill-ramp")
        emitter.particlePositionRange = CGVector(dx: 44, dy: 20)
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 220
        emitter.particleSpeedRange = 120
        emitter.particleLifetime = 1.7
        emitter.particleLifetimeRange = 0.35
        emitter.particleScale = 0.76
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = 1.2
        emitter.particleAlphaSpeed = -0.34
        emitter.particleBirthRate = 500

        emitter.run(
            .customAction(withDuration: 0.45) { [weak emitter] _, elapsedTime in
                let progress = min(max(elapsedTime / 0.45, 0), 1)
                emitter?.particleBirthRate = 500 + (400 * progress)
            },
            withKey: "screen-fill-ramp"
        )
    }

    private func reset() {
        emitter.removeAllActions()
        emitter.particleBirthRate = 0
        configureLaunchSiteExhaust()
        updateRestingEmitterPosition()
    }

    private func configureLaunchSiteExhaust() {
        emitter.particlePositionRange = CGVector(dx: 20, dy: 8)
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi * 0.95
        emitter.particleSpeed = 48
        emitter.particleSpeedRange = 32
        emitter.particleLifetime = 1.35
        emitter.particleLifetimeRange = 0.35
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.14
        emitter.particleScaleSpeed = 0.58
        emitter.particleAlphaSpeed = -0.5
    }

    private func updateRestingEmitterPosition() {
        emitter.position = CGPoint(
            x: size.width / 2,
            y: restingEmitterHeight
        )
    }

    private func makeSmokeTexture() -> SKTexture {
        let size = CGSize(width: 48, height: 48)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [
                UIColor.white.cgColor,
                UIColor.white.withAlphaComponent(0.9).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.62, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }

            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 24, y: 24),
                startRadius: 0,
                endCenter: CGPoint(x: 24, y: 24),
                endRadius: 24,
                options: [.drawsAfterEndLocation]
            )
        }
        return SKTexture(image: image)
    }

}
