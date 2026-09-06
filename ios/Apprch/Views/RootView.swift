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

            case .needsFamily:
                FamilySetupView()

            case .ready(let familyId):
                HomeView(familyId: familyId)
                    .sheet(item: $authVM.pendingTrigger) { pending in
                        ConfirmEventView(triggerId: pending.id, familyId: familyId)
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
