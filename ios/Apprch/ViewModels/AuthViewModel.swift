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
        case needsFamily
        case ready(familyId: String)
    }

    @Published var state: AppState = .loading
    @Published var pendingTrigger: PendingTrigger?
    @Published var linkErrorMessage: String?

    private var authListener: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?

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
            ["displayName": displayName],
            merge: true
        )
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
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

    private func observeUserDoc(uid: String) async {
        userListener?.remove()
        userListener = Firestore.firestore()
            .collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    let familyId = snapshot?.data()?["familyId"] as? String
                    self?.state = familyId.map { .ready(familyId: $0) } ?? .needsFamily
                }
            }
    }
}
