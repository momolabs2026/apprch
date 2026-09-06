import SwiftUI
import UIKit
import FirebaseFirestore
import UserNotifications

struct HomeView: View {
    let groupId: String
    let solo: Bool

    @EnvironmentObject var authVM: AuthViewModel
    @State private var triggers: [Trigger] = []
    @State private var userNames: [String: String] = [:]
    @State private var listener: ListenerRegistration?
    @State private var showingCreate = false
    @State private var showingNotifExplainer = false
    @State private var didAskNotifications = false

    var body: some View {
        NavigationStack {
            Group {
                if triggers.isEmpty {
                    ContentUnavailableView {
                        Label("No triggers yet", systemImage: "dot.radiowaves.left.and.right")
                    } description: {
                        Text(solo
                            ? "Create a Trigger and tap its tag to log it as a reminder for yourself."
                            : "Create a Trigger, write it to an NFC tag in the app, and everyone in your group gets notified when it’s tapped.")
                    } actions: {
                        Button("Create a Trigger") { showingCreate = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(triggers) { trigger in
                        NavigationLink {
                            TriggerDetailView(trigger: trigger, groupId: groupId)
                        } label: {
                            TriggerRow(
                                trigger: trigger,
                                authorName: trigger.lastTriggeredByUid.flatMap { userNames[$0] }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Apprch")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign out") { try? authVM.signOut() }
                        .font(.footnote)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NFCReadButton { url in
                        authVM.handleIncomingURL(url)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Label("Create a Trigger", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateTriggerView(groupId: groupId, solo: solo)
            }
            .alert("Notifications", isPresented: $showingNotifExplainer) {
                Button("Continue") { requestNotificationPermission() }
            } message: {
                Text("Apprch needs permission to notify your group.")
            }
            .onAppear {
                if !solo {
                    askForNotificationsIfNeeded()
                }
                startListening()
            }
            .onDisappear { listener?.remove() }
        }
    }

    private func startListening() {
        listener?.remove()
        listener = Firestore.firestore()
            .collection("triggers")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents.compactMap { doc -> Trigger? in
                    try? doc.data(as: Trigger.self)
                } ?? []
                triggers = docs.sorted { lhs, rhs in
                    let l = lhs.lastTriggeredAt?.dateValue() ?? lhs.createdAt?.dateValue() ?? .distantPast
                    let r = rhs.lastTriggeredAt?.dateValue() ?? rhs.createdAt?.dateValue() ?? .distantPast
                    return l > r
                }
                loadMissingNames(from: triggers)
            }
    }

    private func loadMissingNames(from triggers: [Trigger]) {
        let missing = Set(triggers.compactMap(\.lastTriggeredByUid)).subtracting(userNames.keys)
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

    private func askForNotificationsIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    showingNotifExplainer = true
                }
            }
        }
    }

    private func requestNotificationPermission() {
        guard !didAskNotifications else { return }
        didAskNotifications = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

private struct TriggerRow: View {
    let trigger: Trigger
    let authorName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(trigger.icon)
                .font(.title2)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(trigger.name)
                    .font(.body.weight(.medium))
                Text(activityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var activityText: String {
        guard let last = trigger.lastTriggeredAt else {
            return "No activity yet"
        }
        let who = authorName ?? "Someone"
        return "Last logged \(last.dateValue().formatted(.relative(presentation: .named))) by \(who)"
    }
}
