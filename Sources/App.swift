import AppKit
import ApplicationServices
import IOKit.hid
import SwiftUI

final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var accessibilityGranted = false
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var tapRunning = false
    @Published private(set) var multitouchAvailable = false
    @Published private(set) var devices: [DeviceSnapshot] = []

    private var timer: Timer?

    private init() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)

        // Needed to receive raw finger data from the trackpad.
        inputMonitoringGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if !inputMonitoringGranted { IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) }

        TouchMonitor.shared.start()
        multitouchAvailable = TouchMonitor.shared.available
        tick()
        // Keeps retrying until Accessibility is granted, and picks up newly paired trackpads.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// Re-reads the permission state now instead of waiting for the next timer tick.
    func refresh() { tick() }

    private func tick() {
        accessibilityGranted = AXIsProcessTrusted()
        let im = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if im && !inputMonitoringGranted { TouchMonitor.shared.restart() }
        inputMonitoringGranted = im
        if accessibilityGranted, !EventTapController.shared.isRunning {
            EventTapController.shared.start()
        }
        tapRunning = EventTapController.shared.isRunning
        let snap = TouchMonitor.shared.snapshot()
        if snap.map(\.info.index) != devices.map(\.info.index) || snap.count != devices.count {
            devices = snap
        }
    }

    func rescanDevices() {
        TouchMonitor.shared.restart()
        devices = TouchMonitor.shared.snapshot()
    }

    /// Shows the system prompt when macOS still allows it, otherwise opens the settings pane.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) { openAccessibilitySettings() }
        tick()
    }

    /// macOS only shows the Input Monitoring prompt once; after that the request fails
    /// straight away and the user has to turn it on in System Settings.
    func requestInputMonitoring() {
        if !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) { openInputMonitoringSettings() }
        tick()
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

@main
struct TrackpadRotatorApp: App {
    @StateObject private var model = AppModel.shared
    @StateObject private var store = SettingsStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environmentObject(model)
                .environmentObject(store)
        } label: {
            Image(systemName: store.config.enabled ? "rotate.right.fill" : "rotate.right")
        }
        .menuBarExtraStyle(.window)

        Window("Trackpad Rotator", id: "main") {
            MainWindow()
                .environmentObject(model)
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
    }
}
