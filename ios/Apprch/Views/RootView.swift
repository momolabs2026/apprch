import SwiftUI

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("apprch.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage("apprch.hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var splashDone = false

    var body: some View {
        ZStack {
            appContent

            if showsWelcome {
                WelcomeFlowView(splashDone: $splashDone)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showsWelcome)
        .preferredColorScheme(showsWelcome ? .dark : AppAppearance(rawValue: appearanceRaw)?.colorScheme)
        .onChange(of: showsWelcome) { _, showing in
            if !showing { hasSeenOnboarding = true }
        }
    }

    private var showsWelcome: Bool {
        guard splashDone else { return true }
        switch authVM.state {
        case .loading, .unauthenticated:
            return true
        case .needsGroup, .ready:
            return false
        }
    }

    @ViewBuilder
    private var appContent: some View {
        switch authVM.state {
        case .loading, .unauthenticated:
            Color.clear

        case .needsGroup:
            GroupSetupView()

        case .ready(let active, let spaces):
            HomeView(active: active, spaces: spaces)
                .sheet(item: $authVM.pendingTrigger) { pending in
                    ConfirmEventView(triggerId: pending.id)
                }
                .alert(
                    "This task isn’t available",
                    isPresented: Binding(
                        get: { authVM.linkErrorMessage != nil },
                        set: { if !$0 { authVM.linkErrorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { authVM.linkErrorMessage = nil }
                } message: {
                    Text(authVM.linkErrorMessage ?? "")
                }
                .task(id: spaces.map(\.id).joined(separator: ",")) {
                    await WidgetSnapshotSync.refresh(groupIds: spaces.map(\.id))
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await WidgetSnapshotSync.refresh(groupIds: spaces.map(\.id)) }
                }
        }
    }
}
