import Foundation

/// Permissions, event tap and device state, polled every 2 seconds.
final class StatusViewModel: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var tapRunning = false
    @Published private(set) var multitouchAvailable = false
    @Published private(set) var devices: [DeviceSnapshot] = []

    var allPermissionsGranted: Bool { accessibilityGranted && inputMonitoringGranted }

    private let permissions: PermissionsRepository
    private let trackpad: TrackpadRepository
    private var timer: Timer?

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
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
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
