import Lottie
import SwiftUI

/// Appi, drawn from the splash Lottie. Plays the intro once, then rests on the
/// final frame so every welcome screen shares the same character.
struct AppiView: View {
    let playsIntro: Bool
    var onIntroFinished: () -> Void = {}

    @Environment(AppiController.self) private var appi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRisen: Bool
    @State private var isBreathing = false

    private static let animation = LottieAnimation.named("appi-splash")

    // Figma export layers that duplicate the real status bar and the screen gradient.
    private static let hiddenLayers = ["Splash Screen", "Levels", "Time"]

    init(playsIntro: Bool, onIntroFinished: @escaping () -> Void = {}) {
        self.playsIntro = playsIntro
        self.onIntroFinished = onIntroFinished
        _isRisen = State(initialValue: playsIntro)
    }

    var body: some View {
        GeometryReader { geo in
            let scale = WelcomeLayout.scale(for: geo.size.width)
            let appiHeight = WelcomeLayout.appiHeight * scale

            ZStack(alignment: .bottom) {
                character
                    .frame(width: geo.size.width, height: WelcomeLayout.canvas.height * scale)
                    .allowsHitTesting(false)

                Color.clear
                    .frame(width: 320 * scale, height: appiHeight)
                    .contentShape(.rect)
                    .onTapGesture { appi.hop() }
            }
            .scaleEffect(y: isBreathing ? 1.012 : 1, anchor: .bottom)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: isBreathing)
            .keyframeAnimator(initialValue: Squash(), trigger: reduceMotion ? 0 : appi.hops) { content, squash in
                content.scaleEffect(x: squash.x, y: squash.y, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    CubicKeyframe(0.9, duration: 0.09)
                    SpringKeyframe(1.1, duration: 0.16, spring: .snappy)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.x) {
                    CubicKeyframe(1.06, duration: 0.09)
                    SpringKeyframe(0.96, duration: 0.16, spring: .snappy)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
            }
            .keyframeAnimator(initialValue: 0, trigger: reduceMotion ? 0 : appi.shakes) { content, x in
                content.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-14, duration: 0.07)
                    CubicKeyframe(12, duration: 0.09)
                    CubicKeyframe(-8, duration: 0.08)
                    CubicKeyframe(5, duration: 0.07)
                    SpringKeyframe(0, duration: 0.3)
                }
            }
            .offset(y: isRisen && !appi.isTucked ? 0 : appiHeight + 40)
            .animation(.spring(duration: 0.55, bounce: 0.3), value: appi.isTucked)
            .animation(.spring(duration: 0.7, bounce: 0.35), value: isRisen)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: appi.hops)
        .sensoryFeedback(.error, trigger: appi.shakes)
        .task {
            if !isRisen {
                try? await Task.sleep(for: .milliseconds(150))
                isRisen = true
            }
            if playsIntro {
                try? await Task.sleep(for: .seconds(3.5))
            }
            if !reduceMotion {
                isBreathing = true
            }
        }
    }

    private var character: some View {
        Self.hiddenLayers.reduce(
            LottieView(animation: Self.animation)
                .resizable()
                .playbackMode(playsIntro
                    ? .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
                    : .paused(at: .progress(1)))
                .animationDidFinish { _ in onIntroFinished() }
        ) { view, layer in
            view.valueProvider(
                FloatValueProvider(0),
                for: AnimationKeypath(keypath: "\(layer).Transform.Opacity")
            )
        }
    }
}

private struct Squash {
    var x: CGFloat = 1
    var y: CGFloat = 1
}
