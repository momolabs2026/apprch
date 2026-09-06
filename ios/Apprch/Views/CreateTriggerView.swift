import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

struct CreateTriggerView: View {
    let groupId: String
    let solo: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "📌"
    @State private var notificationMessage = ""
    @State private var messageEdited = false
    @State private var visualization: VisualizationType = .log
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var createdTriggerId: String?

    private let icons = ["📌", "✅", "🏠", "🧹", "💊", "📦", "⭐", "💧", "🍽️", "🔑", "📬", "🗑️", "🚗", "🔔", "🌱", "🧺"]

    var body: some View {
        NavigationStack {
            if let createdTriggerId {
                createdState(triggerId: createdTriggerId)
            } else {
                form
            }
        }
    }

    private var form: some View {
        Form {
            Section("Name") {
                TextField("e.g. Took out the trash", text: $name)
                    .onChange(of: name) { _, newValue in
                        if !messageEdited {
                            notificationMessage = suggestedMessage(for: newValue)
                        }
                    }
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                    ForEach(icons, id: \.self) { candidate in
                        Button {
                            icon = candidate
                            if !messageEdited {
                                notificationMessage = suggestedMessage(for: name)
                            }
                        } label: {
                            Text(candidate)
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(icon == candidate ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(solo ? "Reminder note" : "Notification message") {
                TextField(solo ? "What should you see on this log?" : "What should the group see?", text: $notificationMessage, axis: .vertical)
                    .lineLimit(2...4)
                    .onChange(of: notificationMessage) { _, _ in
                        messageEdited = true
                    }
            }

            Section("Visualization") {
                Picker("Type", selection: $visualization) {
                    ForEach(VisualizationType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                Text(visualization.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Create a Trigger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!canSave || isSaving)
            }
        }
    }

    private func createdState(triggerId: String) -> some View {
        let url = AppLinks.tagURL(triggerId: triggerId)
        return VStack(spacing: 20) {
            Spacer()
            Text(icon)
                .font(.system(size: 64))
            Text(name.isEmpty ? "Trigger created" : name)
                .font(.title2.bold())
            Text("Hold your iPhone to an NFC tag to write this Trigger. You can also copy the link.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(url)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .padding()
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            VStack(spacing: 12) {
                NFCWriteButton(urlString: url)
                Button {
                    UIPasteboard.general.string = url
                } label: {
                    Label("Copy link", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Tag link")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !notificationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func suggestedMessage(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return "\(icon) \(trimmed)"
    }

    private func save() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        errorMessage = nil
        do {
            let ref = Firestore.firestore().collection("triggers").document()
            try await ref.setData([
                "groupId": groupId,
                "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                "icon": icon,
                "notificationMessage": notificationMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                "visualizationType": visualization.rawValue,
                "createdByUid": uid,
                "createdAt": FieldValue.serverTimestamp(),
                "eventCount": 0
            ])
            createdTriggerId = ref.documentID
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
