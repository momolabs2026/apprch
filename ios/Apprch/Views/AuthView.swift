import SwiftUI

/// Sign in and create account. Lives on the welcome stage, so Appi reacts:
/// he ducks while you type, hops on success, and shakes his head on errors.
struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(AppiController.self) private var appi

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showReset = false
    @State private var appeared = false
    @FocusState private var focus: Field?

    private enum Field {
        case name, email, password
    }

    var body: some View {
        GeometryReader { geo in
            let appiInset = WelcomeLayout.appiHeight * WelcomeLayout.scale(for: geo.size.width) + 24

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: focus == nil ? 64 : 32) {
                    brand
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -16)
                        .animation(.spring(duration: 0.6, bounce: 0.25), value: appeared)

                    form
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(.spring(duration: 0.6, bounce: 0.25).delay(0.1), value: appeared)
                }

                Spacer(minLength: focus == nil ? appiInset : 16)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(.rect)
            .onTapGesture { focus = nil }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .tint(ApprchColor.Tertiary.c200)
        .animation(.smooth(duration: 0.35), value: focus)
        .onAppear { appeared = true }
        .onChange(of: focus) { _, field in
            appi.isTucked = field != nil
        }
        .onDisappear { appi.isTucked = false }
        .sheet(isPresented: $showReset) {
            NavigationStack {
                ResetPasswordView(initialEmail: email)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") { showReset = false }
                        }
                    }
            }
        }
    }

    private var brand: some View {
        VStack(spacing: 8) {
            Text("Apprch")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Tap once. Everyone knows.")
                .font(.subheadline)
                .foregroundStyle(ApprchColor.Tertiary.c200)
        }
        .multilineTextAlignment(.center)
    }

    private var form: some View {
        VStack(spacing: 16) {
            if isSignUp {
                WelcomeField(title: "Your name", text: $displayName, isFocused: focus == .name)
                    .focused($focus, equals: .name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .onSubmit { focus = .email }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            WelcomeField(title: "Email", text: $email, isFocused: focus == .email)
                .focused($focus, equals: .email)
                .textContentType(isSignUp ? .emailAddress : .username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focus = .password }

            WelcomeField(title: "Password", text: $password, isSecure: true, isFocused: focus == .password)
                .focused($focus, equals: .password)
                .textContentType(isSignUp ? .newPassword : .password)
                .submitLabel(.go)
                .onSubmit(submit)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            Button(action: submit) {
                Text(isSignUp ? "Create account" : "Sign in")
                    .foregroundStyle(ApprchColor.Neutral.c900)
                    .opacity(isLoading ? 0 : 1)
                    .overlay {
                        if isLoading {
                            ProgressView().tint(ApprchColor.Neutral.c900)
                        }
                    }
                    .padding(.horizontal, 12)
            }
            .font(.subheadline)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)

            Button(action: toggleMode) {
                Group {
                    if isSignUp {
                        Text("Already have an account? \(Text("Sign in").underline())")
                    } else {
                        Text("New here? \(Text("Create account").underline())")
                    }
                }
                .font(.footnote)
                .foregroundStyle(ApprchColor.Tertiary.c200)
            }
            .buttonStyle(.plain)

            if !isSignUp {
                Button("Forgot password?") { showReset = true }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .buttonStyle(.plain)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
    }

    private var formValid: Bool {
        AuthEmail.isComplete(email)
            && password.count >= 6
            && (!isSignUp || !displayName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func toggleMode() {
        withAnimation(.snappy) {
            isSignUp.toggle()
            errorMessage = nil
        }
        appi.hop()
    }

    private func submit() {
        guard !isLoading else { return }
        guard formValid else {
            withAnimation(.snappy) {
                errorMessage = isSignUp && displayName.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Add your name to create an account."
                    : "Enter your email and a password with at least 6 characters."
            }
            appi.shake()
            return
        }
        focus = nil
        isLoading = true
        withAnimation(.snappy) { errorMessage = nil }
        Task {
            do {
                if isSignUp {
                    try await authVM.signUp(email: email, password: password, displayName: displayName)
                } else {
                    try await authVM.signIn(email: email, password: password)
                }
                appi.hop()
            } catch {
                withAnimation(.snappy) {
                    errorMessage = AuthUserFacing.message(for: error)
                }
                appi.shake()
            }
            isLoading = false
        }
    }
}

private struct WelcomeField: View {
    let title: String
    @Binding var text: String
    var isSecure = false
    let isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text, prompt: prompt)
            } else {
                TextField(title, text: $text, prompt: prompt)
            }
        }
        .font(.body.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isFocused ? ApprchColor.Tertiary.c200 : Color.white.opacity(0.24))
                .frame(height: 1)
                .animation(.smooth(duration: 0.2), value: isFocused)
        }
    }

    private var prompt: Text {
        Text(title).foregroundStyle(.white)
    }
}

struct ResetPasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resetSent = false

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Provide the email on your account. We’ll send a reset link there.")
                .foregroundStyle(.secondary)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
                .onChange(of: email) { _, _ in
                    resetSent = false
                    errorMessage = nil
                }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                sendReset()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Reset password")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || !AuthEmail.isComplete(email))

            if resetSent {
                Text("Check your email for a reset link.")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Reset password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendReset() {
        isLoading = true
        errorMessage = nil
        resetSent = false
        Task {
            do {
                try await authVM.sendPasswordReset(email: email)
                resetSent = true
            } catch {
                errorMessage = AuthUserFacing.message(for: error)
            }
            isLoading = false
        }
    }
}

enum AuthEmail {
    static func isComplete(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        return domain.contains(".")
            && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
            && !domain.contains(" ")
    }
}
