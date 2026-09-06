import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Apprch")
                        .font(.largeTitle.bold())
                    Text("Tap once. Everyone knows.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Your name", text: $displayName)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Email", text: $email)
                        .textContentType(isSignUp ? .emailAddress : .username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)

                    if let msg = errorMessage {
                        Text(msg)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    Button {
                        submit()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Create account" : "Sign in")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || !formValid)
                }
                .padding(.horizontal)

                Button {
                    withAnimation { isSignUp.toggle() }
                    errorMessage = nil
                } label: {
                    Text(isSignUp ? "Already have an account? Sign in" : "New here? Create account")
                        .font(.footnote)
                }

                Spacer()
            }
        }
    }

    private var formValid: Bool {
        !email.isEmpty && password.count >= 6 && (!isSignUp || !displayName.isEmpty)
    }

    private func submit() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if isSignUp {
                    try await authVM.signUp(email: email, password: password, displayName: displayName)
                } else {
                    try await authVM.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
