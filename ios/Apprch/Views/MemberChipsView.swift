import SwiftUI
import FirebaseFirestore

struct MemberChipsView: View {
    let groupId: String

    @State private var members: [SpaceMember] = []
    @State private var listener: ListenerRegistration?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(members) { member in
                    HStack(spacing: 6) {
                        MemberAvatar(member: member, size: 22)
                        Text(member.name)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.14), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
        }
        .task(id: groupId) {
            listener?.remove()
            listener = Firestore.firestore().collection("groups").document(groupId)
                .addSnapshotListener { _, _ in
                    Task {
                        members = (try? await GroupStore.members(in: groupId)) ?? []
                    }
                }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }
}

struct MemberAvatar: View {
    let member: SpaceMember
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            if let photo = member.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.secondary.opacity(0.25))
                Text(member.initial)
                    .font(.system(size: size * 0.42, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
