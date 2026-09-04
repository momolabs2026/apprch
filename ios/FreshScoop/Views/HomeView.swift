import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

struct HomeView: View {
    let familyId: String

    @EnvironmentObject var authVM: AuthViewModel
    @State private var events: [FamilyEvent] = []
    @State private var userNames: [String: String] = [:]
    @State private var listener: ListenerRegistration?

    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No events yet",
                        systemImage: "cat.fill",
                        description: Text("Tap the NFC tag to log the first clean!")
                    )
                } else {
                    ForEach(events) { event in
                        EventRow(event: event, authorName: userNames[event.triggeredByUid])
                    }
                }
            }
            .navigationTitle("Fresh Scoop 🐱")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign out") { try? authVM.signOut() }
                        .font(.footnote)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        authVM.triggerEvent(type: "litter_cleaned")
                    } label: {
                        Label("Log clean", systemImage: "checkmark.circle")
                    }
                }
            }
            .onAppear {
                requestNotificationPermission()
                startListening()
            }
            .onDisappear { listener?.remove() }
        }
    }

    private func startListening() {
        listener = Firestore.firestore()
            .collection("events")
            .whereField("familyId", isEqualTo: familyId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, _ in
                let newEvents = snapshot?.documents.compactMap {
                    FamilyEvent(id: $0.documentID, data: $0.data())
                } ?? []
                events = newEvents
                loadMissingNames(from: newEvents)
            }
    }

    private func loadMissingNames(from events: [FamilyEvent]) {
        let missing = Set(events.map(\.triggeredByUid)).subtracting(userNames.keys)
        guard !missing.isEmpty else { return }
        Task {
            for uid in missing {
                if let doc = try? await Firestore.firestore().collection("users").document(uid).getDocument(),
                   let name = doc.data()?["displayName"] as? String {
                    await MainActor.run { userNames[uid] = name }
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - EventRow

private struct EventRow: View {
    let event: FamilyEvent
    let authorName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.displayName)
                .font(.body)
            HStack {
                Text(authorName ?? "Someone")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(event.timestamp, style: .relative)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
