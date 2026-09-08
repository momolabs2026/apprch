import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

struct PendingTrigger: Identifiable {
    let id: String
}

@MainActor
final class AuthViewModel: ObservableObject {

    enum AppState {
        case loading
        case unauthenticated
        case needsGroup
        case ready(active: Space, spaces: [Space])
    }

    @Published var state: AppState = .loading
    @Published var pendingTrigger: PendingTrigger?
    @Published var linkErrorMessage: String?
    @Published var profileName: String = ""
    @Published var profileEmail: String = ""
    @Published var profilePhotoBase64: String?

    private var authListener: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    private var isMigrating = false

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user {
                    await self?.observeUserDoc(uid: user.uid)
                } else {
                    self?.userListener?.remove()
                    self?.state = .unauthenticated
                }
            }
        }
    }

    deinit {
        if let h = authListener { Auth.auth().removeStateDidChangeListener(h) }
        userListener?.remove()
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        try await Firestore.firestore().collection("users").document(result.user.uid).setData(
            GroupStore.directoryFields(displayName: displayName, email: email),
            merge: true
        )
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
        profileName = ""
        profileEmail = ""
        profilePhotoBase64 = nil
    }

    func updateDisplayName(_ name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let user = Auth.auth().currentUser else { throw GroupStoreError.signedOut }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = trimmed
        try await changeRequest.commitChanges()
        try await Firestore.firestore().collection("users").document(user.uid).setData(
            GroupStore.directoryFields(displayName: trimmed, email: user.email),
            merge: true
        )
        profileName = trimmed
    }

    func updatePassword(current: String, new: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw GroupStoreError.signedOut
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: current)
        try await user.reauthenticate(with: credential)
        try await user.updatePassword(to: new)
    }

    func updatePhotoBase64(_ value: String?) async throws {
        guard let user = Auth.auth().currentUser else { throw GroupStoreError.signedOut }
        try await Firestore.firestore().collection("users").document(user.uid).setData(
            ["photoBase64": value ?? FieldValue.delete()],
            merge: true
        )
        profilePhotoBase64 = value
    }

    func presentTrigger(id: String) {
        linkErrorMessage = nil
        pendingTrigger = PendingTrigger(id: id)
    }

    func handleIncomingURL(_ url: URL) {
        if let triggerId = AppLinks.triggerId(from: url) {
            presentTrigger(id: triggerId)
            return
        }
        linkErrorMessage = "This link isn’t a valid Apprch trigger."
    }

    func clearPendingTrigger() {
        pendingTrigger = nil
    }

    func showLinkError(_ message: String) {
        pendingTrigger = nil
        linkErrorMessage = message
    }

    func selectSpace(_ groupId: String) async {
        do {
            try await GroupStore.setActiveSpace(groupId)
        } catch {
            linkErrorMessage = GroupStore.userFacingMessage(for: error)
        }
    }

    private func observeUserDoc(uid: String) async {
        userListener?.remove()
        userListener = Firestore.firestore()
            .collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    await self?.applyUserSnapshot(snapshot?.data())
                }
            }
    }

    private func applyUserSnapshot(_ data: [String: Any]?) async {
        profileEmail = Auth.auth().currentUser?.email ?? ""
        profileName = (data?["displayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? Auth.auth().currentUser?.displayName
            ?? ""
        profilePhotoBase64 = data?["photoBase64"] as? String

        guard let data else {
            state = .needsGroup
            return
        }
        let groupId = (data["activeGroupId"] as? String) ?? (data["groupId"] as? String)
        guard let groupId else {
            state = .needsGroup
            return
        }

        if data["searchName"] == nil, !profileName.isEmpty, !isMigrating,
           let uid = Auth.auth().currentUser?.uid {
            isMigrating = true
            try? await Firestore.firestore().collection("users").document(uid).setData(
                GroupStore.directoryFields(displayName: profileName, email: Auth.auth().currentUser?.email),
                merge: true
            )
            isMigrating = false
        }

        if data["groupIds"] == nil, !isMigrating {
            isMigrating = true
            try? await GroupStore.migrateLegacyUserIfNeeded()
            isMigrating = false
        }

        let spaces = (try? await GroupStore.spaces()) ?? []
        let solo = data["solo"] as? Bool ?? false
        let active = spaces.first(where: { $0.id == groupId })
            ?? Space(id: groupId, name: solo ? "Solo" : "Group", solo: solo)
        var all = spaces
        if !all.contains(where: { $0.id == active.id }) {
            all.insert(active, at: 0)
        }
        state = .ready(active: active, spaces: all)
    }
}
