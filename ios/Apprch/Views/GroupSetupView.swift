import SwiftUI
import FirebaseFunctions

struct GroupSetupView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var mode: Mode = .choose
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case choose, create, join }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title.bold())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                switch mode {
                case .choose:
                    VStack(spacing: 16) {
                        Button("Use solo") {
                            Task { await startSolo() }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(isLoading)

                        Button("Create a group") {
                            withAnimation { mode = .create }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(isLoading)

                        Button("Join with invite code") {
                            withAnimation { mode = .join }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(isLoading)

                        if isLoading {
                            ProgressView()
                        }
                        errorLabel
                    }
                    .padding(.horizontal)

                case .create:
                    VStack(spacing: 16) {
                        TextField("Group name (e.g. The Delfinos)", text: $groupName)
                            .textFieldStyle(.roundedBorder)

                        errorLabel
                        submitButton("Create group") { await createGroup() }
                        backButton
                    }
                    .padding(.horizontal)

                case .join:
                    VStack(spacing: 16) {
                        TextField("Invite code", text: $inviteCode)
                            .textFieldStyle(.roundedBorder)
                            .textCase(.uppercase)
                            .textInputAutocapitalization(.characters)

                        errorLabel
                        submitButton("Join group") { await joinGroup() }
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

    private var title: String {
        switch mode {
        case .choose: return "How do you want to use Apprch?"
        case .create: return "Create a group"
        case .join: return "Join a group"
        }
    }

    private var subtitle: String {
        switch mode {
        case .choose: return "Solo is a private log for you. A group notifies everyone you invite."
        case .create: return "Triggers are shared with everyone you invite."
        case .join: return "Enter the invite code from someone already in the group."
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
            .disabled(isLoading)
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

    private func startSolo() async {
        isLoading = true
        errorMessage = nil
        do {
            let fn = Functions.functions().httpsCallable("createGroup")
            _ = try await fn.call(["solo": true])
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createGroup() async {
        guard !groupName.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let fn = Functions.functions().httpsCallable("createGroup")
            _ = try await fn.call(["name": groupName])
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func joinGroup() async {
        guard !inviteCode.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let fn = Functions.functions().httpsCallable("joinGroup")
            _ = try await fn.call(["inviteCode": inviteCode.uppercased()])
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
