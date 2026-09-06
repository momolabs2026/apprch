import SwiftUI

struct NFCWriteButton: View {
    let urlString: String
    @StateObject private var nfc = NFCTagController()

    var body: some View {
        VStack(spacing: 8) {
            Button {
                guard let url = URL(string: urlString) else { return }
                nfc.write(url: url)
            } label: {
                Label("Write to tag", systemImage: "wave.3.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if !NFCTagController.isAvailable {
                Text(NFCTagController.unavailableMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            statusLabel
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch nfc.status {
        case .idle:
            EmptyView()
        case .success(let message):
            Text(message).font(.caption).foregroundStyle(.green)
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.red)
        }
    }
}

struct NFCReadButton: View {
    let onURL: (URL) -> Void
    @StateObject private var nfc = NFCTagController()

    var body: some View {
        Button {
            nfc.read(onURL: onURL)
        } label: {
            Label("Read tag", systemImage: "wave.3.right.circle")
        }
    }
}
