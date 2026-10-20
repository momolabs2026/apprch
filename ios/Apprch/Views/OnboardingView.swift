import Lottie
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case doTheTask
    case tapToComplete
    case keepTrack

    var title: String {
        switch self {
        case .doTheTask: return "Do the task"
        case .tapToComplete: return "Tap to mark it done"
        case .keepTrack: return "Keep track"
        }
    }

    var animation: LottieAnimation? {
        switch self {
        case .doTheTask: return LottieAnimation.named("apprch-step1-do-the-task")
        case .tapToComplete: return LottieAnimation.named("apprch-step2-tap-to-complete")
        case .keepTrack: return LottieAnimation.named("apprch-step3-keep-track")
        }
    }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
}

/// Steps advance on their own once each animation has played, on tap, or on swipe.
/// Swiping past the last step continues to sign in.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(AppiController.self) private var appi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @ScaledMetric(relativeTo: .largeTitle) private var titleHeight: CGFloat = 41

    @State private var current: OnboardingStep? = .doTheTask
    @State private var isInteracting = false
    @State private var isFinishing = false
    @State private var appeared = false

    private static let stepDuration: Duration = .seconds(4.4)
    private static let dotsTopPadding: CGFloat = 52
    private static let dotsHeight: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let scale = WelcomeLayout.scale(for: geo.size.width)
            let bottomInset = WelcomeLayout.onboardingBottomInset * scale
            let chrome = 24 + titleHeight + Self.dotsTopPadding + Self.dotsHeight + 16
            let side = max(140, min(325 * scale, geo.size.height - bottomInset - chrome))

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                pager(side: side)
                    .frame(height: side + 24 + titleHeight)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.35, anchor: .bottom)
                    .offset(y: appeared || reduceMotion ? 0 : bottomInset * 0.6)
                    .animation(.spring(duration: 0.8, bounce: 0.3), value: appeared)

                PageDots(
                    count: OnboardingStep.allCases.count,
                    index: current?.rawValue ?? 0,
                    onSelect: select
                )
                .padding(.top, Self.dotsTopPadding)
                .opacity(appeared ? 1 : 0)
                .animation(.smooth(duration: 0.5).delay(0.25), value: appeared)
            }
            .padding(.bottom, bottomInset)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear { appeared = true }
        .onChange(of: current) { appi.beam() }
        .task(id: AutoAdvance(step: current, isPaused: isInteracting || voiceOverEnabled)) {
            guard !isInteracting, !voiceOverEnabled else { return }
            try? await Task.sleep(for: Self.stepDuration)
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func pager(side: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    OnboardingPage(
                        step: step,
                        side: side,
                        titleHeight: titleHeight,
                        isActive: current == step,
                        reduceMotion: reduceMotion
                    )
                    .containerRelativeFrame(.horizontal)
                    .contentShape(.rect)
                    .onTapGesture(perform: advance)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(step.next == nil ? "Continues to sign in" : "Shows the next step")
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $current)
        .onScrollPhaseChange { _, phase in
            isInteracting = phase == .interacting
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.x - (geo.contentSize.width - geo.containerSize.width)
        } action: { _, overscroll in
            if overscroll > 56 { finish() }
        }
    }

    private func advance() {
        guard let next = (current ?? .doTheTask).next else {
            finish()
            return
        }
        withAnimation(.smooth(duration: 0.55)) {
            current = next
        }
    }

    private func select(_ index: Int) {
        guard let step = OnboardingStep(rawValue: index) else { return }
        withAnimation(.smooth(duration: 0.55)) {
            current = step
        }
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        onFinish()
    }
}

private struct AutoAdvance: Hashable {
    let step: OnboardingStep?
    let isPaused: Bool
}

private struct OnboardingPage: View {
    let step: OnboardingStep
    let side: CGFloat
    let titleHeight: CGFloat
    let isActive: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 24) {
            LottieView(animation: step.animation)
                .resizable()
                .playbackMode(isActive
                    ? .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
                    : .paused(at: .progress(0)))
                .frame(width: side, height: side)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .scaleEffect(reduceMotion ? 1 : 1 - abs(phase.value) * 0.3)
                        .rotationEffect(.degrees(reduceMotion ? 0 : phase.value * 12))
                        .opacity(1 - abs(phase.value) * 0.6)
                }
                .accessibilityHidden(true)

            Text(step.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: titleHeight)
                .padding(.horizontal, 24)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .offset(x: reduceMotion ? 0 : phase.value * 90)
                        .opacity(1 - abs(phase.value))
                }
        }
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { dot in
                Circle()
                    .fill(dot == index ? ApprchColor.Tertiary.c300 : Color.white.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dot == index ? 1.15 : 1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
        }
        .animation(.snappy, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step")
        .accessibilityValue("\(index + 1) of \(count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment where index < count - 1: onSelect(index + 1)
            case .decrement where index > 0: onSelect(index - 1)
            default: break
            }
        }
    }
}
