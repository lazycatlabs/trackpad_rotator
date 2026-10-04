import Foundation

struct TouchPoint: Identifiable {
    var id: Int32
    var state: Int32
    var x: Float // 0..1, left -> right
    var y: Float // 0..1, bottom -> top (MultitouchSupport convention)
    var size: Float

    var isTouching: Bool { (3...5).contains(state) }
}

struct DeviceSnapshot: Identifiable {
    var id: Int32 { info.index }
    var info: MTBDeviceInfo
    var touches: [TouchPoint] = []
    var lastTouch: CFAbsoluteTime = 0
    /// Finger movement (mm, +x right, +y down in the pad's frame) not yet consumed
    /// by the event tap. Tracked from the centroid of the touching fingers.
    var pendingMotion = (x: 0.0, y: 0.0)
    var lastCentroid: (x: Double, y: Double)?
    var lastFingerIDs: Set<Int32> = []
    var edgeSwipe = EdgeSwipeTracker()

    var widthMM: Double { Double(info.width) / 100 }
    var heightMM: Double { Double(info.height) / 100 }

    /// Magic Mouse is also a multitouch device; it is taller than it is wide.
    var isTrackpad: Bool {
        guard info.width > 0, info.height > 0 else { return true }
        return info.width > info.height
    }

    func matches(_ target: DeviceTarget) -> Bool {
        guard isTrackpad else { return false }
        switch target {
        case .externalTrackpads: return !info.builtIn
        case .allTrackpads: return true
        }
    }

    var name: String {
        if !isTrackpad { return "Magic Mouse / other surface" }
        return info.builtIn ? "Built‑in trackpad" : "Magic Trackpad"
    }
}

/// Listens to raw finger data so we know *which* device is driving the pointer.
final class TouchMonitor {
    static let shared = TouchMonitor()

    /// How long after the last finger lifts we still treat events as coming from the
    /// trackpad (covers trailing pointer events and tap-to-click movement).
    private let releaseGrace: CFAbsoluteTime = 0.12

    private let devices = Locked<[Int32: DeviceSnapshot]>([:])
    private(set) var available = false
    private var probeTimer: Timer?

    func start() {
        available = MTBAvailable()
        guard available else { return }
        restart()
        probeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.rescanIfNeeded()
        }
    }

    func restart() {
        let count = MTBStart(touchHandler)
        var map: [Int32: DeviceSnapshot] = [:]
        if count > 0 {
            for i in 0..<count {
                var info = MTBDeviceInfo()
                if MTBGetDeviceInfo(i, &info) {
                    map[i] = DeviceSnapshot(info: info)
                }
            }
        }
        devices.set(map)
    }

    private func rescanIfNeeded() {
        let probed = MTBProbeDeviceCount()
        if probed >= 0, probed != MTBDeviceCount() {
            restart()
        }
    }

    fileprivate func handle(index: Int32, touches: UnsafePointer<MTBTouch>?, count: Int32) {
        var points: [TouchPoint] = []
        if let touches, count > 0 {
            points.reserveCapacity(Int(count))
            for i in 0..<Int(count) {
                let t = touches[i]
                points.append(TouchPoint(id: t.identifier, state: t.state, x: t.x, y: t.y, size: t.size))
            }
        }
        let now = CFAbsoluteTimeGetCurrent()
        let cfg = SettingsStore.engine.get()
        let edgeSwipeOn = cfg.enabled && !cfg.transform.isIdentity
        let openNotificationCenter = devices.mutate { map -> Bool in
            guard var d = map[index] else { return false }
            d.touches = points
            let touching = points.filter(\.isTouching)
            if !touching.isEmpty { d.lastTouch = now }

            // Accumulate centroid motion while the same set of fingers stays down.
            let ids = Set(touching.map(\.id))
            if touching.isEmpty || d.info.width <= 0 {
                d.lastCentroid = nil
            } else {
                let n = Double(touching.count)
                let cx = touching.reduce(0.0) { $0 + Double($1.x) } / n * d.widthMM
                let cy = touching.reduce(0.0) { $0 - Double($1.y) } / n * d.heightMM // flip to +y down
                if let last = d.lastCentroid, ids == d.lastFingerIDs {
                    d.pendingMotion.x += cx - last.x
                    d.pendingMotion.y += cy - last.y
                }
                d.lastCentroid = (cx, cy)
            }
            d.lastFingerIDs = ids

            var fired = false
            if edgeSwipeOn, d.matches(cfg.target) {
                fired = d.edgeSwipe.update(touching: touching, widthMM: d.widthMM, heightMM: d.heightMM,
                                           transform: cfg.transform, now: now)
            } else {
                d.edgeSwipe = EdgeSwipeTracker()
            }
            map[index] = d
            return fired
        }
        if openNotificationCenter {
            DispatchQueue.main.async { NotificationCenterUI.open() }
        }
    }

    /// True while fingers that came down at your right edge are on a device matching `target`.
    func isEdgeSwipeActive(_ target: DeviceTarget) -> Bool {
        devices.mutate { map in map.values.contains { $0.matches(target) && $0.edgeSwipe.active } }
    }

    /// True while a finger is on (or just left) a device matching `target`.
    func isTargetActive(_ target: DeviceTarget) -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        return devices.mutate { map in
            map.values.contains { $0.matches(target) && now - $0.lastTouch < releaseGrace }
        }
    }

    /// Returns and clears the finger motion (mm, pad frame) since the last call,
    /// summed over devices matching `target`.
    func consumeMotion(_ target: DeviceTarget) -> (x: Double, y: Double) {
        devices.mutate { map in
            var total = (x: 0.0, y: 0.0)
            for key in map.keys {
                guard var d = map[key] else { continue }
                if d.matches(target) {
                    total.x += d.pendingMotion.x
                    total.y += d.pendingMotion.y
                }
                d.pendingMotion = (0, 0)
                map[key] = d
            }
            return total
        }
    }

    func debugDescription() -> String {
        let now = CFAbsoluteTimeGetCurrent()
        return snapshot().map { d in
            let states = d.touches.map { String($0.state) }.joined(separator: ",")
            let age = d.lastTouch == 0 ? "never" : String(format: "%.2fs", now - d.lastTouch)
            return "[#\(d.info.index) builtIn=\(d.info.builtIn) family=\(d.info.familyID) size=\(d.info.width)x\(d.info.height) trackpad=\(d.isTrackpad) lastTouch=\(age) states=\(states)]"
        }.joined(separator: " ")
    }

    func snapshot() -> [DeviceSnapshot] {
        devices.get().values.sorted { $0.info.index < $1.info.index }
    }
}

private let touchHandler: MTBTouchHandler = { index, touches, count, _ in
    TouchMonitor.shared.handle(index: index, touches: touches, count: count)
}
