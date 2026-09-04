import SwiftUI
import FirebaseFunctions

struct ConfirmEventView: View {
    let eventType: String
    let familyId: String

    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    private var displayName: String {
        switch eventType {
        case "litter_cleaned": return "Momo's litter box was cleaned"
        default: return eventType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("🐱")
                .font(.system(size: 80))

            Text(displayName)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Send a push notification to your family?")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if didSend {
                Label("Notification sent!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                VStack(spacing: 12) {
                    if let msg = errorMessage {
                        Text(msg).foregroundStyle(.red).font(.caption)
                    }

                    Button {
                        send()
                    } label: {
                        if isSending {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Send notification").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending)

                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .onChange(of: didSend) { sent in
            if sent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
        }
    }

    private func send() {
        isSending = true
        errorMessage = nil
        Task {
            do {
                let fn = Functions.functions().httpsCallable("logEvent")
                _ = try await fn.call(["type": eventType, "familyId": familyId])
                didSend = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}
