import SwiftUI

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            switch authVM.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .unauthenticated:
                AuthView()

            case .needsGroup:
                GroupSetupView()

            case .ready(let groupId, let solo):
                HomeView(groupId: groupId, solo: solo)
                    .sheet(item: $authVM.pendingTrigger) { pending in
                        ConfirmEventView(triggerId: pending.id, groupId: groupId, solo: solo)
                    }
                    .alert(
                        "This trigger isn’t available",
                        isPresented: Binding(
                            get: { authVM.linkErrorMessage != nil },
                            set: { if !$0 { authVM.linkErrorMessage = nil } }
                        )
                    ) {
                        Button("OK", role: .cancel) { authVM.linkErrorMessage = nil }
                    } message: {
                        Text(authVM.linkErrorMessage ?? "")
                    }
            }
        }
    }
}
