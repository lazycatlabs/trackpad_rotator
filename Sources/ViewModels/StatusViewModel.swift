import Foundation
import Observation

/// Permissions, event tap and device state, polled every 2 seconds.
@MainActor @Observable
final class StatusViewModel {
    private(set) var accessibilityGranted = false
    private(set) var inputMonitoringGranted = false
    private(set) var tapRunning = false
    private(set) var multitouchAvailable = false
    private(set) var devices: [DeviceSnapshot] = []

    var allPermissionsGranted: Bool { accessibilityGranted && inputMonitoringGranted }

    @ObservationIgnored private let permissions: PermissionsRepository
    @ObservationIgnored private let trackpad: TrackpadRepository

    init(permissions: PermissionsRepository = .shared, trackpad: TrackpadRepository = .shared) {
        self.permissions = permissions
        self.trackpad = trackpad

        accessibilityGranted = permissions.promptAccessibility()
        inputMonitoringGranted = permissions.inputMonitoringGranted
        if !inputMonitoringGranted { permissions.promptInputMonitoring() }

        trackpad.startMonitoring()
        multitouchAvailable = trackpad.multitouchAvailable
        tick()
        // Keeps retrying until Accessibility is granted, and picks up newly paired trackpads.
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.tick()
            }
        }
    }

    /// Re-reads the permission state now instead of waiting for the next timer tick.
    func refresh() { tick() }

    private func tick() {
        accessibilityGranted = permissions.accessibilityGranted
        let im = permissions.inputMonitoringGranted
        if im && !inputMonitoringGranted { trackpad.restartMonitoring() }
        inputMonitoringGranted = im
        if accessibilityGranted, !trackpad.tapRunning { trackpad.startTap() }
        tapRunning = trackpad.tapRunning
        let snap = trackpad.devices()
        if snap.map(\.info.index) != devices.map(\.info.index) || snap.count != devices.count {
            devices = snap
        }
    }

    func rescanDevices() {
        trackpad.restartMonitoring()
        devices = trackpad.devices()
    }

    /// Shows the system prompt when macOS still allows it, otherwise opens the settings pane.
    func requestAccessibility() {
        if !permissions.promptAccessibility() { permissions.openAccessibilitySettings() }
        tick()
    }

    func requestInputMonitoring() {
        if !permissions.promptInputMonitoring() { permissions.openInputMonitoringSettings() }
        tick()
    }

    func openAccessibilitySettings() { permissions.openAccessibilitySettings() }
    func openInputMonitoringSettings() { permissions.openInputMonitoringSettings() }

    // Live reads for views that redraw on their own timeline; not @Published on purpose.
    func liveDevices() -> [DeviceSnapshot] { trackpad.devices() }
    func isTargetActive(_ target: DeviceTarget) -> Bool { trackpad.isTargetActive(target) }
}
