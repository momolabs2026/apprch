import Combine
import Foundation
import CoreNFC

@MainActor
final class NFCTagController: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case success(String)
        case failed(String)
    }

    @Published var status: Status = .idle

    static var unavailableMessage: String {
        #if PERSONAL_TEAM
        "NFC needs a paid Apple Developer team. This Debug build can run on your iPhone, but it can’t write or read tags yet."
        #else
        "NFC needs a physical iPhone, not the Simulator."
        #endif
    }

    static var isAvailable: Bool {
        #if PERSONAL_TEAM
        false
        #else
        NFCNDEFReaderSession.readingAvailable
        #endif
    }

    private var session: NFCNDEFReaderSession?
    private var urlToWrite: URL?
    private var onRead: ((URL) -> Void)?

    func write(url: URL) {
        guard Self.isAvailable else {
            status = .failed(Self.unavailableMessage)
            return
        }
        urlToWrite = url
        onRead = nil
        status = .idle
        beginSession(alert: "Hold the top of your iPhone on the tag to write this Task.")
    }

    func read(onURL: @escaping (URL) -> Void) {
        guard Self.isAvailable else {
            status = .failed(Self.unavailableMessage)
            return
        }
        urlToWrite = nil
        onRead = onURL
        status = .idle
        beginSession(alert: "Hold the top of your iPhone on the tag to read it.")
    }

    private func beginSession(alert: String) {
        session?.invalidate()
        let next = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        next.alertMessage = alert
        session = next
        next.begin()
    }

    private func finish(session: NFCNDEFReaderSession, message: String, success: Bool) {
        session.alertMessage = message
        session.invalidate()
        Task { @MainActor in
            self.status = success ? .success(message) : .failed(message)
        }
    }
}

extension NFCTagController: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let nfcError = error as NSError
        if nfcError.domain == NFCReaderError.errorDomain,
           nfcError.code == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
            return
        }
        Task { @MainActor in
            self.status = .failed(error.localizedDescription)
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [any NFCNDEFTag]) {
        guard let tag = tags.first else { return }
        if tags.count > 1 {
            session.alertMessage = "More than one tag found. Try again with a single tag."
            session.restartPolling()
            return
        }

        session.connect(to: tag) { error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }
            Task { @MainActor in
                if let url = self.urlToWrite {
                    self.write(url, to: tag, session: session)
                } else {
                    self.read(from: tag, session: session)
                }
            }
        }
    }

    private func write(_ url: URL, to tag: any NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.queryNDEFStatus { status, capacity, error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }
            guard status != .notSupported else {
                session.invalidate(errorMessage: "This tag isn’t writable.")
                return
            }
            guard status != .readOnly else {
                session.invalidate(errorMessage: "This tag is locked and can’t be written.")
                return
            }
            guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
                session.invalidate(errorMessage: "Couldn’t build the tag link.")
                return
            }
            let message = NFCNDEFMessage(records: [payload])
            guard message.length <= capacity else {
                session.invalidate(errorMessage: "This tag doesn’t have enough space.")
                return
            }
            tag.writeNDEF(message) { error in
                if let error {
                    session.invalidate(errorMessage: error.localizedDescription)
                    return
                }
                Task { @MainActor in
                    self.finish(session: session, message: "Tag written.", success: true)
                }
            }
        }
    }

    private func read(from tag: any NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { message, error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }
            let url = message?.records.compactMap { $0.wellKnownTypeURIPayload() }.first
            guard let url else {
                session.invalidate(errorMessage: "No link found on this tag.")
                return
            }
            Task { @MainActor in
                self.onRead?(url)
                self.finish(session: session, message: "Tag read.", success: true)
            }
        }
    }
}
