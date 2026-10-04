import Foundation
import ServiceManagement

/// How the trackpad is physically turned relative to you.
enum Rotation: Int, CaseIterable, Identifiable {
    case none = 0
    case cw90 = 90
    case r180 = 180
    case ccw90 = 270

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: "0°"
        case .cw90: "90° ↻"
        case .r180: "180°"
        case .ccw90: "90° ↺"
        }
    }

    var longLabel: String {
        switch self {
        case .none: "Normal (not rotated)"
        case .cw90: "Rotated 90° clockwise"
        case .r180: "Upside down (180°)"
        case .ccw90: "Rotated 90° counter‑clockwise"
        }
    }
}

enum DeviceTarget: Int, CaseIterable, Identifiable {
    case externalTrackpads = 0
    case allTrackpads = 1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .externalTrackpads: "External trackpads only (Magic Trackpad)"
        case .allTrackpads: "All trackpads (incl. built‑in)"
        }
    }
}

/// Maps a vector in the trackpad's own frame to a vector in your frame.
/// Coordinates are screen-style: +x right, +y down.
struct AxisTransform: Equatable {
    var rotation: Rotation = .none
    var swapXY = false
    var invertX = false
    var invertY = false

    func apply(_ x: Double, _ y: Double) -> (x: Double, y: Double) {
        var a = x, b = y
        switch rotation {
        case .none: break
        // Pad turned clockwise: its +x points down at you, its +y points left.
        case .cw90: (a, b) = (-y, x)
        case .r180: (a, b) = (-x, -y)
        case .ccw90: (a, b) = (y, -x)
        }
        if swapXY { swap(&a, &b) }
        if invertX { a = -a }
        if invertY { b = -b }
        return (a, b)
    }

    var isIdentity: Bool {
        let p = apply(1, 2)
        return p.x == 1 && p.y == 2
    }
}

struct EngineConfig: Equatable {
    var enabled = true
    var transform = AxisTransform()
    var applyToPointer = true
    var applyToScroll = true
    var target: DeviceTarget = .externalTrackpads
    /// Multipliers on top of macOS's own tracking/scroll speed.
    var pointerSpeed = 1.0
    var scrollSpeed = 1.0
}

/// Small lock-protected box for state shared between the event tap,
/// the multitouch thread and the UI.
final class Locked<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) { self.value = value }

    func get() -> T {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set(_ newValue: T) {
        lock.lock(); value = newValue; lock.unlock()
    }

    func mutate<R>(_ body: (inout T) -> R) -> R {
        lock.lock(); defer { lock.unlock() }
        return body(&value)
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    /// Snapshot read by the event tap on every event.
    static let engine = Locked(EngineConfig())

    @Published var config: EngineConfig {
        didSet {
            guard config != oldValue else { return }
            save()
            Self.engine.set(config)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("TrackpadRotator: launch at login change failed: \(error)")
            }
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        var c = EngineConfig()
        let d = UserDefaults.standard
        if d.object(forKey: "enabled") != nil { c.enabled = d.bool(forKey: "enabled") }
        c.transform.rotation = Rotation(rawValue: d.integer(forKey: "rotation")) ?? .none
        c.transform.swapXY = d.bool(forKey: "swapXY")
        c.transform.invertX = d.bool(forKey: "invertX")
        c.transform.invertY = d.bool(forKey: "invertY")
        if d.object(forKey: "applyToPointer") != nil { c.applyToPointer = d.bool(forKey: "applyToPointer") }
        if d.object(forKey: "applyToScroll") != nil { c.applyToScroll = d.bool(forKey: "applyToScroll") }
        c.target = DeviceTarget(rawValue: d.integer(forKey: "target")) ?? .externalTrackpads
        if d.object(forKey: "pointerSpeed") != nil { c.pointerSpeed = d.double(forKey: "pointerSpeed") }
        if d.object(forKey: "scrollSpeed") != nil { c.scrollSpeed = d.double(forKey: "scrollSpeed") }
        config = c
        // Turn on launch at login once, the first time the installed copy runs.
        // Dev builds elsewhere are skipped so they don't register a temporary path.
        if !d.bool(forKey: "launchAtLoginDefaultApplied"),
           Bundle.main.bundlePath.hasPrefix("/Applications/") {
            d.set(true, forKey: "launchAtLoginDefaultApplied")
            try? SMAppService.mainApp.register()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        Self.engine.set(c)
    }

    private func save() {
        defaults.set(config.enabled, forKey: "enabled")
        defaults.set(config.transform.rotation.rawValue, forKey: "rotation")
        defaults.set(config.transform.swapXY, forKey: "swapXY")
        defaults.set(config.transform.invertX, forKey: "invertX")
        defaults.set(config.transform.invertY, forKey: "invertY")
        defaults.set(config.applyToPointer, forKey: "applyToPointer")
        defaults.set(config.applyToScroll, forKey: "applyToScroll")
        defaults.set(config.target.rawValue, forKey: "target")
        defaults.set(config.pointerSpeed, forKey: "pointerSpeed")
        defaults.set(config.scrollSpeed, forKey: "scrollSpeed")
    }

    func resetAxes() {
        config.transform = AxisTransform(rotation: config.transform.rotation)
    }
}
