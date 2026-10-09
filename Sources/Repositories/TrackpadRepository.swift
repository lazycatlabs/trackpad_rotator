import Foundation

/// The UI's only door into the engine: trackpad discovery, live touches and the event tap.
@MainActor
final class TrackpadRepository {
    static let shared = TrackpadRepository()

    private init() {}

    func startMonitoring() { TouchMonitor.shared.start() }
    func restartMonitoring() { TouchMonitor.shared.restart() }
    var multitouchAvailable: Bool { TouchMonitor.shared.available }

    /// Current devices with their latest touches; cheap enough to call every frame.
    func devices() -> [DeviceSnapshot] { TouchMonitor.shared.snapshot() }
    func isTargetActive(_ target: DeviceTarget) -> Bool { TouchMonitor.shared.isTargetActive(target) }

    var tapRunning: Bool { EventTapController.shared.isRunning }
    func startTap() { EventTapController.shared.start() }
}
