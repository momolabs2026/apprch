import SwiftUI

/// Sign in, create account, and password reset. Lives on the welcome stage, so Appi
/// reacts: he ducks while you type, cheers on success, and shakes his head on errors.
struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(AppiController.self) private var appi

    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resetSent = false
    @State private var appeared = false
    @FocusState private var focus: Field?

    private enum Mode {
        case signIn, signUp, reset
    }

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
            .background {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { focus = nil }
                    .allowsHitTesting(focus != nil)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .tint(ApprchColor.Tertiary.c200)
        .animation(.smooth(duration: 0.35), value: focus)
        .onAppear { appeared = true }
        .onChange(of: focus) { _, field in
            appi.isTucked = field != nil
        }
        .onDisappear { appi.isTucked = false }
        .onChange(of: email) { resetSent = false }
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
            if mode == .reset {
                Text(resetSent
                    ? "Check your inbox for a reset link."
                    : "Enter your account email and we’ll send you a reset link.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if mode == .signUp {
                WelcomeField(title: "Your name", text: $displayName, isFocused: focus == .name)
                    .focused($focus, equals: .name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .onSubmit { focus = .email }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            WelcomeField(title: "Email", text: $email, isFocused: focus == .email)
                .focused($focus, equals: .email)
                .textContentType(mode == .signUp ? .emailAddress : .username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(mode == .reset ? .send : .next)
                .onSubmit {
                    if mode == .reset { submit() } else { focus = .password }
                }

            if mode != .reset {
                WelcomeField(title: "Password", text: $password, isSecure: true, isFocused: focus == .password)
                    .focused($focus, equals: .password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            Button(action: submit) {
                Text(submitTitle)
                    .contentTransition(.opacity)
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

            footer
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            switch mode {
            case .signIn:
                Button { switchMode(to: .signUp) } label: {
                    Text("Create account")
                        .fontWeight(.semibold)
                        .foregroundStyle(ApprchColor.Tertiary.c200)
                }

                Circle()
                    .fill(.white.opacity(0.4))
                    .frame(width: 3, height: 3)
                    .transition(.opacity)

                Button("Forgot password?") { switchMode(to: .reset) }
                    .foregroundStyle(.white.opacity(0.8))
                    .transition(.opacity)
            case .signUp:
                Button { switchMode(to: .signIn) } label: {
                    Text("Have an account? \(Text("Sign in").fontWeight(.semibold).foregroundStyle(ApprchColor.Tertiary.c200))")
                        .foregroundStyle(.white.opacity(0.8))
                }
            case .reset:
                Button { switchMode(to: .signIn) } label: {
                    Text("Remembered it? \(Text("Sign in").fontWeight(.semibold).foregroundStyle(ApprchColor.Tertiary.c200))")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .font(.subheadline)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private var submitTitle: String {
        switch mode {
        case .signIn: return "Sign in"
        case .signUp: return "Create account"
        case .reset: return resetSent ? "Send again" : "Send reset link"
        }
    }

    private var missingName: Bool {
        mode == .signUp && displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var formValid: Bool {
        AuthEmail.isComplete(email)
            && (mode == .reset || password.count >= 6)
            && !missingName
    }

    private var invalidFormMessage: String {
        if mode == .reset { return "Enter the email on your account." }
        if missingName { return "Add your name to create an account." }
        return "Enter your email and a password with at least 6 characters."
    }

    private func switchMode(to newMode: Mode) {
        withAnimation(.snappy) {
            mode = newMode
            errorMessage = nil
            resetSent = false
        }
        appi.hop()
    }

    private func submit() {
        guard !isLoading else { return }
        guard formValid else {
            withAnimation(.snappy) {
                errorMessage = invalidFormMessage
            }
            appi.shake()
            return
        }
        focus = nil
        isLoading = true
        withAnimation(.snappy) { errorMessage = nil }
        Task {
            do {
                switch mode {
                case .signIn:
                    try await authVM.signIn(email: email, password: password)
                case .signUp:
                    try await authVM.signUp(email: email, password: password, displayName: displayName)
                case .reset:
                    try await authVM.sendPasswordReset(email: email)
                    withAnimation(.snappy) { resetSent = true }
                }
                appi.cheer()
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
