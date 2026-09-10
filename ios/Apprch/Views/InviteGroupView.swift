import SwiftUI
import UIKit
import FirebaseAuth

struct InviteGroupView: View {
    let groupId: String

    @Environment(\.dismiss) private var dismiss

    @State private var inviteCode: String?
    @State private var isSolo = false
    @State private var isLoading = true
    @State private var copied = false
    @State private var errorMessage: String?

    @State private var query = ""
    @State private var results: [SpaceMember] = []
    @State private var memberIds: Set<String> = []
    @State private var addedIds: Set<String> = []
    @State private var isSearching = false
    @State private var addingId: String?
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    private var excludedIds: Set<String> {
        var ids = memberIds.union(addedIds)
        if let me = Auth.auth().currentUser?.uid {
            ids.insert(me)
        }
        return ids
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isSolo {
                    ContentUnavailableView(
                        "Solo stays private",
                        systemImage: "person",
                        description: Text("Open a Task and choose Share this Task to move it into a group. Solo itself doesn’t get invite codes.")
                    )
                } else if let inviteCode {
                    inviteBody(inviteCode)
                } else if let errorMessage {
                    ContentUnavailableView("Couldn’t load invite", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
        .onChange(of: query) { _, _ in
            scheduleSearch()
        }
        .onDisappear { searchTask?.cancel() }
    }

    private func inviteBody(_ code: String) -> some View {
        List {
            Section {
                TextField("Search by name or email", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching")
                            .foregroundStyle(.secondary)
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Text("Type at least 2 characters.")
                        .foregroundStyle(.secondary)
                } else if results.isEmpty {
                    Text("No one matches that yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { person in
                        personRow(person)
                    }
                }

                if let searchError {
                    Text(searchError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            } header: {
                Text("Find someone")
            } footer: {
                Text("Add them here if they already have Apprch. If they don’t, share the code below.")
            }

            Section("Or share the invite code") {
                Text("Anyone with this code can join this group. Your Solo space stays yours.")
                    .foregroundStyle(.secondary)

                Text(code)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .frame(maxWidth: .infinity)
                    .textSelection(.enabled)

                ShareLink(item: "Join my Apprch group with invite code \(code)") {
                    Label("Share code", systemImage: "square.and.arrow.up")
                }

                Button {
                    UIPasteboard.general.string = code
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy code", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
            }
        }
    }

    private func personRow(_ person: SpaceMember) -> some View {
        HStack(spacing: 12) {
            MemberAvatar(member: person, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                if let email = person.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if addedIds.contains(person.id) || memberIds.contains(person.id) {
                Text("Added")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Button("Add") {
                    Task { await add(person) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(addingId == person.id)
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let info = try await GroupStore.inviteCode(for: groupId)
            isSolo = info.solo
            if info.solo {
                inviteCode = nil
            } else if let code = info.code {
                inviteCode = code
            } else {
                inviteCode = try await GroupStore.enableInvites(groupId: groupId)
            }
            if !info.solo {
                let members = try await GroupStore.members(in: groupId)
                memberIds = Set(members.map(\.id))
            }
        } catch {
            errorMessage = GroupStore.userFacingMessage(for: error)
        }
        isLoading = false
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func runSearch() async {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchError = nil
        guard needle.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            results = try await GroupStore.searchUsers(query: needle, excluding: excludedIds)
        } catch {
            searchError = GroupStore.userFacingMessage(for: error)
            results = []
        }
        isSearching = false
    }

    private func add(_ person: SpaceMember) async {
        addingId = person.id
        searchError = nil
        do {
            try await GroupStore.addMember(person.id, toGroupId: groupId)
            addedIds.insert(person.id)
            memberIds.insert(person.id)
            results.removeAll { $0.id == person.id }
        } catch {
            searchError = GroupStore.userFacingMessage(for: error)
        }
        addingId = nil
    }
}
