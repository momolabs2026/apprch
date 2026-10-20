import Lottie
import SwiftUI

/// Appi, drawn from `appi.json` (built by `ios/AnimationSources/build_appi.py`).
/// Plays the splash intro once, then idles and beams on request so every
/// welcome screen shares the same living character.
struct AppiView: View {
    let playsIntro: Bool
    var onIntroFinished: () -> Void = {}

    @Environment(AppiController.self) private var appi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clip: Clip
    @State private var isRisen: Bool

    private static let animation = LottieAnimation.named("appi")

    private enum Clip: String {
        case intro, settle, idle, beam
    }

    init(playsIntro: Bool, onIntroFinished: @escaping () -> Void = {}) {
        self.playsIntro = playsIntro
        self.onIntroFinished = onIntroFinished
        _clip = State(initialValue: playsIntro ? .intro : .idle)
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
                    .onTapGesture { appi.beam() }
            }
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
            .keyframeAnimator(initialValue: CGFloat(0), trigger: reduceMotion ? 0 : appi.shakes) { content, x in
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
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: appi.beams)
        .sensoryFeedback(.error, trigger: appi.shakes)
        .onChange(of: appi.beams) {
            if clip == .idle { clip = .beam }
        }
        .task {
            guard !isRisen else { return }
            try? await Task.sleep(for: .milliseconds(150))
            isRisen = true
        }
    }

    private var character: some View {
        LottieView(animation: Self.animation)
            .resizable()
            .playbackMode(.playing(.marker(clip.rawValue, loopMode: clip == .idle ? .loop : .playOnce)))
            .animationDidFinish { completed in
                guard completed else { return }
                switch clip {
                case .intro:
                    clip = .settle
                    onIntroFinished()
                case .settle, .beam:
                    clip = .idle
                case .idle:
                    break
                }
            }
    }
}

private struct Squash {
    var x: CGFloat = 1
    var y: CGFloat = 1
}
