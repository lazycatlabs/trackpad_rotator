import AppKit
import ApplicationServices
import IOKit.hid

/// Reads and requests the macOS privacy permissions the app needs.
@MainActor
final class PermissionsRepository {
    static let shared = PermissionsRepository()

    private init() {}

    var accessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Needed to receive raw finger data from the trackpad.
    var inputMonitoringGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Shows the system prompt when macOS still allows it. Returns whether access is granted.
    @discardableResult
    func promptAccessibility() -> Bool {
        // The value of kAXTrustedCheckOptionPrompt, which Swift 6 treats as mutable global state.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// macOS only shows the Input Monitoring prompt once; after that the request fails
    /// straight away and the user has to turn it on in System Settings.
    @discardableResult
    func promptInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
