import SwiftUI
import PhotosUI
import UIKit
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var passwordSaved = false
    @AppStorage("apprch.appearance") private var appearanceRaw = AppAppearance.system.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        profileImage
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Text(authVM.profilePhotoBase64 == nil ? "Add photo" : "Change photo")
                            }
                            if authVM.profilePhotoBase64 != nil {
                                Button("Remove photo", role: .destructive) {
                                    Task { await savePhoto(nil) }
                                }
                                .font(.footnote)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Name") {
                    TextField("Your name", text: $name)
                    Button("Save name") {
                        Task { await saveName() }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Email") {
                    Text(authVM.profileEmail.isEmpty ? "No email" : authVM.profileEmail)
                        .foregroundStyle(.secondary)
                }

                Section("Password") {
                    SecureField("Current password", text: $currentPassword)
                    SecureField("New password (6+ characters)", text: $newPassword)
                    Button("Update password") {
                        Task { await savePassword() }
                    }
                    .disabled(isSaving || currentPassword.isEmpty || newPassword.count < 6)
                    if passwordSaved {
                        Text("Password updated")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        try? authVM.signOut()
                        dismiss()
                    }
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                name = authVM.profileName
            }
            .onChange(of: pickerItem) { _, item in
                Task { await loadPickedPhoto(item) }
            }
        }
    }

    private var profileImage: some View {
        ZStack {
            if let image = SpaceMember.image(from: authVM.profilePhotoBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.secondary.opacity(0.2))
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
    }

    private func saveName() async {
        isSaving = true
        errorMessage = nil
        do {
            try await authVM.updateDisplayName(name)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func savePassword() async {
        isSaving = true
        errorMessage = nil
        passwordSaved = false
        do {
            try await authVM.updatePassword(current: currentPassword, new: newPassword)
            currentPassword = ""
            newPassword = ""
            passwordSaved = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            await savePhoto(Self.encodedAvatar(from: image))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePhoto(_ value: String?) async {
        isSaving = true
        errorMessage = nil
        do {
            try await authVM.updatePhotoBase64(value)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private static func encodedAvatar(from image: UIImage) -> String? {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let squared = renderer.image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let scaled = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (size.width - scaled.width) / 2, y: (size.height - scaled.height) / 2)
            image.draw(in: CGRect(origin: origin, size: scaled))
        }
        return squared.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }
}
