import SwiftUI
import FirebaseFunctions

struct FamilySetupView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var mode: Mode = .choose
    @State private var familyName = ""
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case choose, create, join }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Text("Set up your family")
                    .font(.title.bold())

                switch mode {
                case .choose:
                    VStack(spacing: 16) {
                        Button("Create a new family") {
                            withAnimation { mode = .create }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                        Button("Join with invite code") {
                            withAnimation { mode = .join }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)

                case .create:
                    VStack(spacing: 16) {
                        TextField("Family name (e.g. The Delfinos)", text: $familyName)
                            .textFieldStyle(.roundedBorder)

                        errorLabel
                        submitButton("Create family") { await createFamily() }
                        backButton
                    }
                    .padding(.horizontal)

                case .join:
                    VStack(spacing: 16) {
                        TextField("Invite code", text: $inviteCode)
                            .textFieldStyle(.roundedBorder)
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)

                        errorLabel
                        submitButton("Join family") { await joinFamily() }
                        backButton
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") { try? authVM.signOut() }
                        .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder private var errorLabel: some View {
        if let msg = errorMessage {
            Text(msg).foregroundStyle(.red).font(.caption)
        }
    }

    private var backButton: some View {
        Button("Back") { withAnimation { mode = .choose } }
            .font(.footnote)
    }

    private func submitButton(_ label: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(label).frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }

    private func createFamily() async {
        guard !familyName.isEmpty else { return }
        isLoading = true; errorMessage = nil
        do {
            let fn = Functions.functions().httpsCallable("createFamily")
            _ = try await fn.call(["name": familyName])
            // Auth state listener picks up the new familyId and transitions state
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func joinFamily() async {
        guard !inviteCode.isEmpty else { return }
        isLoading = true; errorMessage = nil
        do {
            let fn = Functions.functions().httpsCallable("joinFamily")
            _ = try await fn.call(["inviteCode": inviteCode.uppercased()])
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
