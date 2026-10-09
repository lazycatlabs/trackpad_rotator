import Foundation
import ServiceManagement

/// Persists settings in UserDefaults and publishes them to the engine.
@MainActor
final class SettingsRepository {
    static let shared = SettingsRepository()
    /// Snapshot read by the event tap on every event.
    nonisolated static let engine = Locked(EngineConfig())

    private let defaults = UserDefaults.standard

    private init() {}

    func load() -> EngineConfig {
        var c = EngineConfig()
        let d = defaults
        if d.object(forKey: "enabled") != nil { c.enabled = d.bool(forKey: "enabled") }
        c.transform.rotation = Rotation(rawValue: d.integer(forKey: "rotation")) ?? .none
        c.transform.swapXY = d.bool(forKey: "swapXY")
        c.transform.invertX = d.bool(forKey: "invertX")
        c.transform.invertY = d.bool(forKey: "invertY")
        if d.object(forKey: "applyToPointer") != nil { c.applyToPointer = d.bool(forKey: "applyToPointer") }
        if d.object(forKey: "applyToScroll") != nil { c.applyToScroll = d.bool(forKey: "applyToScroll") }
        if d.object(forKey: "swipeNavigation") != nil { c.swipeNavigation = d.bool(forKey: "swipeNavigation") }
        if d.object(forKey: "notificationCenterSwipe") != nil {
            c.notificationCenterSwipe = d.bool(forKey: "notificationCenterSwipe")
        }
        if d.object(forKey: "dockSwipes") != nil { c.dockSwipes = d.bool(forKey: "dockSwipes") }
        c.target = DeviceTarget(rawValue: d.integer(forKey: "target")) ?? .externalTrackpads
        if d.object(forKey: "pointerSpeed") != nil { c.pointerSpeed = d.double(forKey: "pointerSpeed") }
        if d.object(forKey: "scrollSpeed") != nil { c.scrollSpeed = d.double(forKey: "scrollSpeed") }
        Self.engine.set(c)
        return c
    }

    func save(_ config: EngineConfig) {
        defaults.set(config.enabled, forKey: "enabled")
        defaults.set(config.transform.rotation.rawValue, forKey: "rotation")
        defaults.set(config.transform.swapXY, forKey: "swapXY")
        defaults.set(config.transform.invertX, forKey: "invertX")
        defaults.set(config.transform.invertY, forKey: "invertY")
        defaults.set(config.applyToPointer, forKey: "applyToPointer")
        defaults.set(config.applyToScroll, forKey: "applyToScroll")
        defaults.set(config.swipeNavigation, forKey: "swipeNavigation")
        defaults.set(config.notificationCenterSwipe, forKey: "notificationCenterSwipe")
        defaults.set(config.dockSwipes, forKey: "dockSwipes")
        defaults.set(config.target.rawValue, forKey: "target")
        defaults.set(config.pointerSpeed, forKey: "pointerSpeed")
        defaults.set(config.scrollSpeed, forKey: "scrollSpeed")
        Self.engine.set(config)
    }

    // MARK: Launch at login

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("TrackpadRotator: launch at login change failed: \(error)")
        }
    }

    /// Turn on launch at login once, the first time the installed copy runs.
    /// Dev builds elsewhere are skipped so they don't register a temporary path.
    func applyLaunchAtLoginDefault() {
        guard !defaults.bool(forKey: "launchAtLoginDefaultApplied"),
              Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        defaults.set(true, forKey: "launchAtLoginDefaultApplied")
        try? SMAppService.mainApp.register()
    }
}
