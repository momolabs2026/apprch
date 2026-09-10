import SwiftUI
import UIKit
import FirebaseFirestore
import UserNotifications

private enum HomeSection: Hashable {
    case solo
    case groups
}

struct HomeView: View {
    let active: Space
    let spaces: [Space]

    @EnvironmentObject var authVM: AuthViewModel
    @State private var section: HomeSection
    @State private var showingAddGroup = false
    @State private var showingJoin = false
    @State private var showingNotifExplainer = false
    @State private var showingProfile = false
    @State private var didAskNotifications = false

    init(active: Space, spaces: [Space]) {
        self.active = active
        self.spaces = spaces
        _section = State(initialValue: active.solo ? .solo : .groups)
    }

    private var personal: Space? { spaces.first(where: \.solo) }
    private var groups: [Space] { spaces.filter { !$0.solo } }

    private var navigationTitle: String {
        switch section {
        case .solo:
            return "Solo"
        case .groups:
            if groups.count == 1 { return groups[0].title }
            return "Groups"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Space", selection: $section) {
                    Text("Solo").tag(HomeSection.solo)
                    Text("Groups").tag(HomeSection.groups)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)

                switch section {
                case .solo:
                    if let personal {
                        TriggerListView(space: personal, spaces: spaces)
                    } else {
                        ContentUnavailableView(
                            "No Solo space yet",
                            systemImage: "person",
                            description: Text("Pull to refresh, or sign out and back in.")
                        )
                    }
                case .groups:
                    groupsContent
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Label("You", systemImage: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if NFCTagController.isAvailable {
                        NFCReadButton { url in
                            authVM.handleIncomingURL(url)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupSheet()
            }
            .sheet(isPresented: $showingJoin) {
                JoinGroupSheet()
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
            .alert("Notifications", isPresented: $showingNotifExplainer) {
                Button("Continue") { requestNotificationPermission() }
            } message: {
                Text("Apprch needs permission to notify your group.")
            }
            .onAppear {
                syncActiveSpace()
                if section == .groups, !groups.isEmpty {
                    askForNotificationsIfNeeded()
                }
            }
            .onChange(of: section) { _, _ in
                syncActiveSpace()
            }
            .onChange(of: active.id) { _, _ in
                section = active.solo ? .solo : .groups
            }
        }
    }

    @ViewBuilder private var groupsContent: some View {
        switch groups.count {
        case 0:
            ContentUnavailableView {
                Label("No groups yet", systemImage: "person.3")
            } description: {
                Text("Solo stays yours. A group is a separate space you can move Tasks into.")
            } actions: {
                Button("Create a group") { showingAddGroup = true }
                    .buttonStyle(.borderedProminent)
                Button("Join a group") { showingJoin = true }
                    .buttonStyle(.bordered)
            }
        case 1:
            TriggerListView(space: groups[0], spaces: spaces)
        default:
            List {
                ForEach(groups) { group in
                    NavigationLink {
                        TriggerListView(space: group, spaces: spaces)
                            .navigationTitle(group.title)
                            .navigationBarTitleDisplayMode(.large)
                    } label: {
                        Label(group.title, systemImage: "person.3")
                    }
                }
                Section {
                    Button("Create a group") { showingAddGroup = true }
                    Button("Join a group") { showingJoin = true }
                }
            }
        }
    }

    private func syncActiveSpace() {
        let target: Space?
        switch section {
        case .solo:
            target = personal
        case .groups:
            target = groups.count == 1 ? groups.first : (active.solo ? groups.first : active)
        }
        guard let target, target.id != active.id else { return }
        Task { await authVM.selectSpace(target.id) }
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

private struct TriggerListView: View {
    let space: Space
    let spaces: [Space]

    @EnvironmentObject var authVM: AuthViewModel
    @State private var triggers: [Trigger] = []
    @State private var userNames: [String: String] = [:]
    @State private var listener: ListenerRegistration?
    @State private var showingCreate = false
    @State private var showingInvite = false
    @State private var togglingId: String?
    @State private var toggleError: String?

    var body: some View {
        VStack(spacing: 0) {
            if !space.solo {
                MemberChipsView(groupId: space.id)
                    .padding(.bottom, 8)
            }

            if triggers.isEmpty {
                ContentUnavailableView {
                    Label("No tasks yet", systemImage: "dot.radiowaves.left.and.right")
                } description: {
                    Text(space.solo
                        ? "Tasks in Solo are only for you. Open one later to move it into a group."
                        : "Tasks here are shared with this group.")
                } actions: {
                    Button("Create a Task") { showingCreate = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(triggers) { trigger in
                    HStack(spacing: 12) {
                        NavigationLink {
                            TriggerDetailView(trigger: trigger, spaces: spaces)
                        } label: {
                            TriggerRow(
                                trigger: trigger,
                                authorName: trigger.lastLoggedByUid.flatMap { userNames[$0] }
                            )
                        }
                        Button {
                            Task { await toggleToday(trigger) }
                        } label: {
                            Image(systemName: trigger.isCompletedToday ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(trigger.isCompletedToday ? trigger.accent : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(togglingId == trigger.id)
                        .accessibilityLabel(trigger.isCompletedToday ? "Mark not done today" : "Mark done today")
                    }
                }
            }
        }
        .toolbar {
            if !space.solo {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInvite = true
                    } label: {
                        Label("Invite", systemImage: "person.badge.plus")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Label("Create a Task", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateTriggerView(groupId: space.id, solo: space.solo)
        }
        .sheet(isPresented: $showingInvite) {
            InviteGroupView(groupId: space.id)
        }
        .alert("Couldn’t update", isPresented: Binding(
            get: { toggleError != nil },
            set: { if !$0 { toggleError = nil } }
        )) {
            Button("OK", role: .cancel) { toggleError = nil }
        } message: {
            Text(toggleError ?? "")
        }
        .onAppear {
            startListening()
            if !space.solo {
                Task { await authVM.selectSpace(space.id) }
            }
        }
        .onDisappear { listener?.remove() }
    }

    private func toggleToday(_ trigger: Trigger) async {
        guard let id = trigger.id else { return }
        togglingId = id
        do {
            try await EventStore.toggleToday(
                triggerId: id,
                groupId: trigger.groupId,
                currentlyComplete: trigger.isCompletedToday
            )
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } catch {
            toggleError = EventStore.userFacingMessage(for: error)
        }
        togglingId = nil
    }

    private func startListening() {
        listener?.remove()
        listener = Firestore.firestore()
            .collection("tasks")
            .whereField("groupId", isEqualTo: space.id)
            .addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents.compactMap { doc -> Trigger? in
                    try? doc.data(as: Trigger.self)
                } ?? []
                triggers = docs.sorted { lhs, rhs in
                    let l = lhs.lastLoggedAt?.dateValue() ?? lhs.createdAt?.dateValue() ?? .distantPast
                    let r = rhs.lastLoggedAt?.dateValue() ?? rhs.createdAt?.dateValue() ?? .distantPast
                    return l > r
                }
                loadMissingNames(from: triggers)
            }
    }

    private func loadMissingNames(from triggers: [Trigger]) {
        let missing = Set(triggers.compactMap(\.lastLoggedByUid)).subtracting(userNames.keys)
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

private struct AddGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("This stays next to your Solo space") {
                    TextField("Group name (e.g. The Delfinos)", text: $name)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Create a group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() async {
        isSaving = true
        errorMessage = nil
        do {
            try await GroupStore.create(name: name.trimmingCharacters(in: .whitespacesAndNewlines), solo: false)
            dismiss()
        } catch {
            errorMessage = GroupStore.userFacingMessage(for: error)
        }
        isSaving = false
    }
}

private struct JoinGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Solo space stays yours") {
                    TextField("Invite code", text: $code)
                        .textCase(.uppercase)
                        .textInputAutocapitalization(.characters)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Join a group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        Task { await join() }
                    }
                    .disabled(isSaving || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func join() async {
        isSaving = true
        errorMessage = nil
        do {
            try await GroupStore.join(inviteCode: code)
            dismiss()
        } catch {
            errorMessage = GroupStore.userFacingMessage(for: error)
        }
        isSaving = false
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
        guard let last = trigger.lastLoggedAt else {
            if (trigger.eventCount ?? 0) > 0 {
                return "Logged"
            }
            return "No activity yet"
        }
        let who = authorName ?? "Someone"
        return "Last logged \(last.dateValue().formatted(.relative(presentation: .named))) by \(who)"
    }
}
