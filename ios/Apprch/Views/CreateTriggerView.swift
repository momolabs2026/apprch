import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

struct CreateTriggerView: View {
    let groupId: String
    let solo: Bool
    var editing: Trigger? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var icon: String
    @State private var notificationMessage: String
    @State private var messageEdited: Bool
    @State private var visualization: VisualizationType
    @State private var accentHex: String

    init(groupId: String, solo: Bool, editing: Trigger? = nil) {
        self.groupId = groupId
        self.solo = solo
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _icon = State(initialValue: editing?.icon ?? "📌")
        _notificationMessage = State(initialValue: editing?.notificationMessage ?? "")
        _messageEdited = State(initialValue: editing != nil)
        _visualization = State(initialValue: editing?.visualization ?? .log)
        _accentHex = State(initialValue: editing?.accentColorHex ?? TriggerAccent.fallbackHex)
    }
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var createdTriggerId: String?
    @State private var copied = false

    private let icons = ["📌", "✅", "🏠", "🧹", "💊", "📦", "⭐", "💧", "🍽️", "🔑", "📬", "🗑️", "🚗", "🔔", "🌱", "🧺"]

    var body: some View {
        NavigationStack {
            if let createdTriggerId, editing == nil {
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

            if let editing {
                Section("NFC tag") {
                    Text(editing.tagURLString)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Text("Write this as a URI in NFC Tools. A website URL opens Safari instead of the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    NFCWriteButton(urlString: editing.tagURLString)
                    Button {
                        UIPasteboard.general.string = editing.tagURLString
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy link", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }

            Section("Accent color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                    ForEach(TriggerAccent.presets, id: \.self) { hex in
                        Button {
                            accentHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .overlay {
                                    if accentHex.uppercased() == hex.uppercased() {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Accent \(hex)")
                    }
                }
                ColorPicker("Custom color", selection: accentBinding, supportsOpacity: false)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(editing == nil ? "Create a Trigger" : "Edit Trigger")
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
            Text("Copy this into NFC Tools as a URI (not a website). Tapping the tag opens Apprch and logs it.")
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
            let payload: [String: Any] = [
                "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                "icon": icon,
                "notificationMessage": notificationMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                "visualizationType": visualization.rawValue,
                "accentColorHex": accentHex
            ]
            if let editing, let id = editing.id {
                try await Firestore.firestore().collection("triggers").document(id).updateData(payload)
                dismiss()
            } else {
                var data = payload
                data["groupId"] = groupId
                data["createdByUid"] = uid
                data["createdAt"] = FieldValue.serverTimestamp()
                data["eventCount"] = 0
                let ref = Firestore.firestore().collection("triggers").document()
                try await ref.setData(data)
                createdTriggerId = ref.documentID
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { Color(hex: accentHex) },
            set: { accentHex = $0.hexString() }
        )
    }
}
