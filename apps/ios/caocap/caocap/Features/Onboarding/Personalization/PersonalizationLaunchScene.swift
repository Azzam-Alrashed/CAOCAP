import AudioToolbox
import SpriteKit
import SwiftUI

struct PersonalizationLaunchScene: View {
    let rocketImageName: String
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller = PersonalizationLaunchController()
    @State private var smokeScene = PersonalizationLaunchSmokeScene()
    @State private var audio = PersonalizationLaunchAudioPlayer()
    @State private var secondsRemaining: Int = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                launchEnvironment(in: geometry)

                VStack {
                    if !controller.isLaunching {
                        Text("\(secondsRemaining)")
                            .font(.system(size: 84, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.top, 140)
                            .contentTransition(.numericText())
                            .opacity(controller.titleOpacity)
                    }

                    Spacer()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                startLaunch(in: geometry)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                startLaunch(in: geometry)
            }
            .task {
                secondsRemaining = 10
                for s in stride(from: 10, through: 1, by: -1) {
                    if Task.isCancelled || controller.isLaunching { break }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        secondsRemaining = s
                    }
                    AudioServicesPlaySystemSound(1104)
                    UISelectionFeedbackGenerator().selectionChanged()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                if !Task.isCancelled && !controller.isLaunching {
                    startLaunch(in: geometry)
                }
            }
        }
        .onChange(of: controller.phase) { _, phase in
            if reduceMotion {
                smokeScene.stop()
            } else {
                smokeScene.transition(to: phase)
            }
        }
        .onDisappear {
            controller.cancel(audio: audio)
            smokeScene.stop()
        }
    }

    private func launchEnvironment(in geometry: GeometryProxy) -> some View {
        let launchPadWidth = geometry.size.width / 1.5
        let launchSiteBottomPadding = geometry.size.width * 0.05
        let rocketRestingHeight = launchPadWidth * 0.2
        let emitterHeight = launchSiteBottomPadding + rocketRestingHeight

        return ZStack {
            Image("OnboardingLaunchGround")
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)

            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(.black.opacity(0.16))
                    .frame(
                        width: launchPadWidth * 0.82,
                        height: launchPadWidth * 0.15
                    )
                    .blur(radius: 8)

                Image("OnboardingLaunchPad")
                    .resizable()
                    .scaledToFit()
                    .frame(width: launchPadWidth)
            }
            .padding(.bottom, launchSiteBottomPadding)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)

            SpriteView(
                scene: smokeScene,
                options: [.allowsTransparency]
            )
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                smokeScene.setRestingEmitterHeight(emitterHeight)
            }
            .onChange(of: emitterHeight) { _, newHeight in
                smokeScene.setRestingEmitterHeight(newHeight)
            }

            ZStack(alignment: .bottom) {
                Image(rocketImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: launchPadWidth * 0.5)
                    .padding(.bottom, launchPadWidth * 0.2)
                    .offset(
                        x: controller.rocketShakeOffset,
                        y: controller.rocketVerticalOffset
                    )
            }
            .padding(.bottom, launchSiteBottomPadding)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        controller.isLaunching
            ? "Launch in progress."
            : "Tap to launch your coding journey."
    }

    private func startLaunch(in geometry: GeometryProxy) {
        controller.start(
            travelDistance: geometry.size.height + 320,
            reduceMotion: reduceMotion,
            audio: audio,
            onComplete: onComplete
        )
    }
}
