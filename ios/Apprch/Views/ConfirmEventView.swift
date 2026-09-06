import SwiftUI
import FirebaseFirestore
import FirebaseFunctions

struct ConfirmEventView: View {
    let triggerId: String
    let groupId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var trigger: Trigger?
    @State private var loadFailed = false
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let trigger {
                    confirmBody(trigger)
                } else if loadFailed {
                    ContentUnavailableView(
                        "This trigger isn’t available",
                        systemImage: "link.badge.plus",
                        description: Text("It may belong to a different group, or it was deleted.")
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadTrigger() }
        .onChange(of: didSend) { _, sent in
            if sent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            }
        }
    }

    private func confirmBody(_ trigger: Trigger) -> some View {
        VStack(spacing: 28) {
            Spacer()
            Text(trigger.icon)
                .font(.system(size: 72))
            Text(trigger.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Send a notification to your group?")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if didSend {
                Label("Notification sent", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                VStack(spacing: 12) {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
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
        .padding()
    }

    private func loadTrigger() async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("triggers")
                .document(triggerId)
                .getDocument()
            guard snapshot.exists, let loaded = try? snapshot.data(as: Trigger.self) else {
                loadFailed = true
                return
            }
            if loaded.groupId != groupId {
                loadFailed = true
                return
            }
            trigger = loaded
        } catch {
            loadFailed = true
        }
    }

    private func send() {
        isSending = true
        errorMessage = nil
        Task {
            do {
                let fn = Functions.functions().httpsCallable("logEvent")
                _ = try await fn.call(["triggerId": triggerId, "groupId": groupId])
                didSend = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}
