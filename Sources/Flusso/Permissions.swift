import AVFoundation
import Cocoa

enum Permissions {
    static var microphoneGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static var inputMonitoringGranted: Bool { CGPreflightListenEventAccess() }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }

    static func openPrivacyPane(_ anchor: String) {
        let url = "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        NSWorkspace.shared.open(URL(string: url)!)
    }
}
