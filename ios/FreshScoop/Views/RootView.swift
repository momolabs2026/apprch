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
                    .sheet(item: $authVM.pendingEvent) { event in
                        ConfirmEventView(eventType: event.id, familyId: familyId)
                    }
            }
        }
    }
}
