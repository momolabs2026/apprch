import SwiftUI
import UIKit
import FirebaseFirestore

struct TriggerDetailView: View {
    let spaces: [Space]
    @State private var trigger: Trigger
    @State private var events: [TriggerEvent] = []
    @State private var userNames: [String: String] = [:]
    @State private var eventsListener: ListenerRegistration?
    @State private var triggerListener: ListenerRegistration?
    @State private var showingMove = false
    @State private var showingEdit = false
    @State private var historyError: String?
    @EnvironmentObject var authVM: AuthViewModel

    init(trigger: Trigger, spaces: [Space]) {
        self.spaces = spaces
        _trigger = State(initialValue: trigger)
    }

    private var todayCount: Int {
        events.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    private var todaySummary: String {
        switch todayCount {
        case 0: return "Not yet"
        case 1: return "Done once"
        default: return "Done \(todayCount) times"
        }
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(todaySummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(todayCount == 0 ? Color.secondary : trigger.accent)
                }
                if trigger.visualization == .counter {
                    HStack {
                        Text("Total")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(trigger.eventCount ?? events.count)")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            Section("History") {
                if let historyError {
                    Text(historyError)
                        .foregroundStyle(.red)
                } else {
                    ContributionGraphView(events: events, accent: trigger.accent)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    if events.isEmpty {
                        Text("No activity yet. Check the circle on a day you do this.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(events.prefix(8))) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userNames[event.triggeredByUid] ?? "Someone")
                                Text(event.date.apprchRelativeString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(trigger.icon)
                    Text(trigger.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingMove = true
                } label: {
                    Label("Move", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingMove) {
            MoveTriggerView(trigger: trigger, spaces: spaces)
        }
        .sheet(isPresented: $showingEdit) {
            CreateTriggerView(
                groupId: trigger.groupId,
                solo: spaces.first(where: { $0.id == trigger.groupId })?.solo ?? false,
                editing: trigger
            )
        }
        .onAppear { startListening() }
        .onChange(of: trigger.groupId) { _, _ in
            startListening()
        }
        .onDisappear {
            eventsListener?.remove()
            triggerListener?.remove()
        }
    }

    private func startListening() {
        guard let triggerId = trigger.id else { return }

        triggerListener?.remove()
        triggerListener = Firestore.firestore()
            .collection("triggers").document(triggerId)
            .addSnapshotListener { snapshot, _ in
                if let updated = try? snapshot?.data(as: Trigger.self) {
                    trigger = updated
                }
            }

        eventsListener?.remove()
        eventsListener = Firestore.firestore()
            .collection("events")
            .whereField("groupId", isEqualTo: trigger.groupId)
            .whereField("triggerId", isEqualTo: triggerId)
            .limit(to: 400)
            .addSnapshotListener { snapshot, error in
                if let error {
                    historyError = error.localizedDescription
                    return
                }
                historyError = nil
                let newEvents = (snapshot?.documents.compactMap { try? $0.data(as: TriggerEvent.self) } ?? [])
                    .sorted { $0.date > $1.date }
                events = newEvents
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
