import SwiftUI

/// Splash → onboarding → sign in, all on one stage so the gradient and Appi
/// never leave the screen between steps.
struct WelcomeFlowView: View {
    @Binding var splashDone: Bool

    @EnvironmentObject private var authVM: AuthViewModel
    @AppStorage("apprch.hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var appi = AppiController()
    @State private var finishedOnboarding = false

    private enum Phase {
        case splash, onboarding, auth
    }

    var body: some View {
        ZStack {
            WelcomeBackground()

            AppiView(playsIntro: !splashDone, onIntroFinished: finishSplash)

            switch phase {
            case .splash:
                Color.clear
            case .onboarding:
                OnboardingView(onFinish: finishOnboarding)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .auth:
                AuthView()
                    .transition(finishedOnboarding
                        ? .move(edge: .trailing).combined(with: .opacity)
                        : .opacity)
            }
        }
        .environment(appi)
        .task {
            // Fallback in case the splash animation never reports completion.
            try? await Task.sleep(for: .seconds(4))
            finishSplash()
        }
    }

    private var phase: Phase {
        guard splashDone, case .unauthenticated = authVM.state else { return .splash }
        return hasSeenOnboarding || finishedOnboarding ? .auth : .onboarding
    }

    private func finishSplash() {
        guard !splashDone else { return }
        withAnimation(.smooth(duration: 0.6)) {
            splashDone = true
        }
    }

    private func finishOnboarding() {
        appi.beam()
        withAnimation(.smooth(duration: 0.55)) {
            finishedOnboarding = true
        }
        hasSeenOnboarding = true
    }
}

/// Sizes from the 393 × 852 Figma frames; screens scale them by width.
enum WelcomeLayout {
    static let canvas = CGSize(width: 393, height: 852)
    static let appiHeight: CGFloat = 182
    static let onboardingBottomInset: CGFloat = 215

    static func scale(for width: CGFloat) -> CGFloat {
        width / canvas.width
    }
}

struct WelcomeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [ApprchColor.Primary.c500, Color(hex: 0x007AFF)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Lets the welcome screens make Appi react without owning the character.
@MainActor
@Observable
final class AppiController {
    private(set) var hops = 0
    private(set) var beams = 0
    private(set) var shakes = 0
    var isTucked = false

    func hop() { hops += 1 }
    func shake() { shakes += 1 }

    /// Sends out a small NFC ping, like Appi tapping a tag.
    func beam() { beams += 1 }
}
