import SpriteKit
import UIKit

@MainActor
final class PersonalizationLaunchSmokeScene: SKScene {
    private let emitter = SKEmitterNode()
    private let wipeEmitter = SKEmitterNode()
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
            emitter.particleBirthRate = 130
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
        wipeEmitter.removeAllActions()
        wipeEmitter.particleBirthRate = 0
        removeAllActions()
    }

    private func configureEmitter() {
        emitter.particleTexture = makeSmokeTexture()
        emitter.particleBirthRate = 0
        emitter.particleLifetime = 1.05
        emitter.particleLifetimeRange = 0.25
        emitter.particlePositionRange = CGVector(dx: 16, dy: 5)
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = .pi * 0.85
        emitter.particleSpeed = 34
        emitter.particleSpeedRange = 20
        emitter.particleAlpha = 0.92
        emitter.particleAlphaRange = 0.08
        emitter.particleAlphaSpeed = -0.7
        emitter.particleScale = 0.2
        emitter.particleScaleRange = 0.08
        emitter.particleScaleSpeed = 0.48
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

        wipeEmitter.particleTexture = makeSmokeTexture()
        wipeEmitter.particleBirthRate = 0
        wipeEmitter.particleLifetime = 1.2
        wipeEmitter.particleLifetimeRange = 0.35
        wipeEmitter.particlePositionRange = CGVector(dx: 1, dy: 1)
        wipeEmitter.emissionAngleRange = .pi * 2
        wipeEmitter.particleSpeed = 70
        wipeEmitter.particleSpeedRange = 55
        wipeEmitter.particleAlpha = 0.94
        wipeEmitter.particleAlphaRange = 0.12
        wipeEmitter.particleAlphaSpeed = -0.42
        wipeEmitter.particleScale = 0.48
        wipeEmitter.particleScaleRange = 0.24
        wipeEmitter.particleScaleSpeed = 0.72
        wipeEmitter.particleRotationRange = .pi
        wipeEmitter.particleRotationSpeed = 0.25
        wipeEmitter.particleColorBlendFactor = 1
        wipeEmitter.particleColorSequence = smokeColorSequence()
        wipeEmitter.targetNode = self
        wipeEmitter.fieldBitMask = 1
        addChild(wipeEmitter)
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
        emitter.particleBirthRate = 18

        emitter.run(
            .customAction(withDuration: 0.55) { [weak emitter] _, elapsedTime in
                let progress = min(max(elapsedTime / 0.55, 0), 1)
                emitter?.particleBirthRate = 18 + (112 * progress)
            },
            withKey: "ignition-ramp"
        )
    }

    private func beginLiftoff() {
        emitter.removeAction(forKey: "ignition-ramp")
        emitter.particleBirthRate = 95

        let travel = SKAction.moveTo(
            y: size.height * 1.2,
            duration: 0.8
        )
        travel.timingMode = .easeIn

        emitter.run(
            .sequence([
                travel,
                .run { [weak emitter] in
                    emitter?.particleBirthRate = 0
                }
            ]),
            withKey: "liftoff"
        )
    }

    private func beginWipe() {
        emitter.removeAllActions()
        emitter.particleBirthRate = 0
        wipeEmitter.removeAllActions()
        wipeEmitter.position = CGPoint(
            x: size.width / 2,
            y: size.height * 0.38
        )
        wipeEmitter.particlePositionRange = CGVector(
            dx: size.width * 0.92,
            dy: size.height * 0.65
        )
        wipeEmitter.particleBirthRate = 180

        wipeEmitter.run(
            .customAction(withDuration: 0.42) { [weak wipeEmitter] _, elapsedTime in
                let progress = min(max(elapsedTime / 0.42, 0), 1)
                wipeEmitter?.particleBirthRate = 180 + (420 * progress)
            },
            withKey: "screen-fill-ramp"
        )
    }

    private func reset() {
        emitter.removeAllActions()
        emitter.particleBirthRate = 0
        wipeEmitter.removeAllActions()
        wipeEmitter.particleBirthRate = 0
        updateRestingEmitterPosition()
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

    private func smokeColorSequence() -> SKKeyframeSequence {
        SKKeyframeSequence(
            keyframeValues: [
                UIColor.white,
                UIColor(red: 0.78, green: 0.88, blue: 1, alpha: 1),
                UIColor(red: 0.82, green: 0.73, blue: 1, alpha: 1)
            ],
            times: [0, 0.55, 1]
        )
    }
}
