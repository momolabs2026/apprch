import SwiftUI

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
        case .choose: return "Start with Solo, or add a group"
        case .create: return "Create a group"
        case .join: return "Join a group"
        }
    }

    private var subtitle: String {
        switch mode {
        case .choose: return "You’ll always keep a Solo space. Groups are extra spaces you can move Triggers into."
        case .create: return "This adds a group next to your Solo space. Triggers stay private until you move one."
        case .join: return "Enter the invite code. Your Solo space stays yours."
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
            try await GroupStore.create(name: "Solo", solo: true)
        } catch {
            errorMessage = GroupStore.userFacingMessage(for: error)
        }
        isLoading = false
    }

    private func createGroup() async {
        guard !groupName.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await GroupStore.create(name: groupName.trimmingCharacters(in: .whitespacesAndNewlines), solo: false)
        } catch {
            errorMessage = GroupStore.userFacingMessage(for: error)
        }
        isLoading = false
    }

    private func joinGroup() async {
        guard !inviteCode.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await GroupStore.join(inviteCode: inviteCode)
        } catch {
            errorMessage = GroupStore.userFacingMessage(for: error)
        }
        isLoading = false
    }
}
