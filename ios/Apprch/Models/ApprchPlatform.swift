import Foundation

enum ApprchPlatform {
    /// True when the iOS app is running on a Mac (Designed for iPad).
    static var isIOSAppOnMac: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }
}
