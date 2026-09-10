import SwiftUI

struct MoveTriggerView: View {
    let trigger: Trigger
    let spaces: [Space]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var newGroupName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var destinations: [Space] {
        spaces.filter { $0.id != trigger.groupId }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("This Task stays in Solo unless you move it. History moves with it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                if !destinations.isEmpty {
                    Section("Move to an existing space") {
                        ForEach(destinations) { space in
                            Button {
                                Task { await move(to: space.id) }
                            } label: {
                                Label(space.title, systemImage: space.solo ? "person" : "person.3")
                            }
                            .disabled(isSaving)
                        }
                    }
                }

                Section("Or create a new group") {
                    TextField("Group name (e.g. The Delfinos)", text: $newGroupName)
                    Button("Create group with this Task") {
                        Task { await createGroup() }
                    }
                    .disabled(isSaving || newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Share this Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func move(to groupId: String) async {
        guard let triggerId = trigger.id else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await GroupStore.moveTrigger(triggerId, toGroupId: groupId)
            await authVM.selectSpace(groupId)
            dismiss()
        } catch {
            errorMessage = GroupStore.userFacingMessage(for: error)
        }
        isSaving = false
    }

    private func createGroup() async {
        guard let triggerId = trigger.id else { return }
        isSaving = true
        errorMessage = nil
        do {
            _ = try await GroupStore.createGroup(named: newGroupName, movingTriggerId: triggerId)
            dismiss()
        } catch {
            errorMessage = GroupStore.userFacingMessage(for: error)
        }
        isSaving = false
    }
}
