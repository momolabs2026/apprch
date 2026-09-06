import SwiftUI
import UIKit
import FirebaseFirestore

struct TriggerDetailView: View {
    let groupId: String
    @State private var trigger: Trigger
    @State private var events: [TriggerEvent] = []
    @State private var userNames: [String: String] = [:]
    @State private var eventsListener: ListenerRegistration?
    @State private var triggerListener: ListenerRegistration?
    @State private var copied = false
    @EnvironmentObject var authVM: AuthViewModel

    init(trigger: Trigger, groupId: String) {
        self.groupId = groupId
        _trigger = State(initialValue: trigger)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Text(trigger.icon)
                        .font(.largeTitle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trigger.name)
                            .font(.title3.bold())
                        Text(trigger.visualization.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if trigger.visualization == .counter {
                    LabeledContent("Total") {
                        Text("\(trigger.eventCount ?? events.count)")
                            .font(.title3.bold())
                    }
                }
            }

            Section("NFC tag") {
                Text(trigger.tagURLString)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                NFCWriteButton(urlString: trigger.tagURLString)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                Button {
                    UIPasteboard.general.string = trigger.tagURLString
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy link", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
            }

            Section("History") {
                if events.isEmpty {
                    Text("No events yet. Tap the tag or log one below.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userNames[event.triggeredByUid] ?? "Someone")
                            Text(event.date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(trigger.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Log") {
                    if let id = trigger.id {
                        authVM.presentTrigger(id: id)
                    }
                }
            }
        }
        .onAppear { startListening() }
        .onDisappear {
            eventsListener?.remove()
            triggerListener?.remove()
        }
    }

    private func startListening() {
        guard let triggerId = trigger.id else { return }

        triggerListener = Firestore.firestore()
            .collection("triggers").document(triggerId)
            .addSnapshotListener { snapshot, _ in
                if let updated = try? snapshot?.data(as: Trigger.self) {
                    trigger = updated
                }
            }

        eventsListener = Firestore.firestore()
            .collection("events")
            .whereField("triggerId", isEqualTo: triggerId)
            .limit(to: 80)
            .addSnapshotListener { snapshot, _ in
                let newEvents = (snapshot?.documents.compactMap { try? $0.data(as: TriggerEvent.self) } ?? [])
                    .sorted { $0.date > $1.date }
                events = Array(newEvents.prefix(50))
                loadMissingNames(from: newEvents)
            }
    }

    private func loadMissingNames(from events: [TriggerEvent]) {
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
}
