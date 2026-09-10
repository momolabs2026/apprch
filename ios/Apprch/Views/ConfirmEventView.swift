import SwiftUI
import UIKit
import FirebaseFirestore

struct ConfirmEventView: View {
    let triggerId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var trigger: Trigger?
    @State private var loadFailed = false
    @State private var isSending = false
    @State private var didSend = false
    @State private var didAttempt = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed {
                    ContentUnavailableView(
                        "This task isn’t available",
                        systemImage: "link.badge.plus",
                        description: Text("It may belong to a different space, or it was deleted.")
                    )
                } else {
                    statusBody
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isSending)
        .task { await logIfNeeded() }
        .onChange(of: didSend) { _, sent in
            if sent {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
            }
        }
    }

    private var statusBody: some View {
        VStack(spacing: 20) {
            Spacer()
            if let trigger {
                Text(trigger.icon)
                    .font(.system(size: 72))
                Text(trigger.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }

            if didSend {
                Label("Logged", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Try again") {
                    Task { await send() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
                Text("Logging…")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func logIfNeeded() async {
        await loadTrigger()
        guard !didAttempt, trigger != nil else { return }
        didAttempt = true
        await send()
    }

    private func loadTrigger() async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("tasks")
                .document(triggerId)
                .getDocument()
            guard snapshot.exists, let loaded = try? snapshot.data(as: Trigger.self) else {
                loadFailed = true
                return
            }
            trigger = loaded
        } catch {
            loadFailed = true
        }
    }

    private func send() async {
        guard let groupId = trigger?.groupId else { return }
        isSending = true
        errorMessage = nil
        do {
            try await EventStore.log(triggerId: triggerId, groupId: groupId)
            await authVM.selectSpace(groupId)
            didSend = true
        } catch {
            errorMessage = EventStore.userFacingMessage(for: error)
        }
        isSending = false
    }
}
