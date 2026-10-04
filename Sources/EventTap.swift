import AppKit
import CoreGraphics
import os

private let log = Logger(subsystem: "local.trackpadrotator", category: "pointer")

/// Tracks the direction of finger travel from raw multitouch data.
///
/// Both pointer and scroll take their *direction* from this rather than from the
/// driver's deltas: once the pad is turned, the driver's deltas don't line up with
/// the real finger motion. Noise is filtered by waiting for a minimum travel and
/// blending successive directions.
private struct DirectionTracker {
    private(set) var direction: (x: Double, y: Double)?
    private var accum = (x: 0.0, y: 0.0)

    mutating func reset() {
        direction = nil
        accum = (0, 0)
    }

    /// `finger` is travel in mm in the pad's frame; returns the unit direction in your frame.
    mutating func update(finger: (x: Double, y: Double), transform: AxisTransform) -> (x: Double, y: Double)? {
        accum.x += finger.x
        accum.y += finger.y
        let len = hypot(accum.x, accum.y)
        let needed = direction == nil ? 0.12 : 0.25 // mm
        if len >= needed {
            let t = transform.apply(accum.x, accum.y)
            let fresh = (x: t.x / len, y: t.y / len)
            if let old = direction {
                let mx = old.x * 0.45 + fresh.x * 0.55
                let my = old.y * 0.45 + fresh.y * 0.55
                let m = hypot(mx, my)
                direction = m > 1e-6 ? (mx / m, my / m) : fresh
            } else {
                direction = fresh
            }
            accum = (0, 0)
        }
        return direction
    }
}

/// Rewrites pointer and scroll events coming from the rotated trackpad.
final class EventTapController {
    static let shared = EventTapController()

    private var pointerTap: CFMachPort?
    private var scrollTap: CFMachPort?
    private var displayBounds: [CGRect] = []

    var isRunning: Bool { pointerTap != nil && scrollTap != nil }

    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        CGAssociateMouseAndMouseCursorPosition(1)
        refreshDisplays()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshDisplays() }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in CGAssociateMouseAndMouseCursorPosition(1) }

        // Pointer: as early as possible, so the cursor can be repositioned before it's drawn.
        let pointerTypes: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        // Scroll: at the session level, which is exactly what apps receive. The gesture events
        // that accompany each scroll (used by AppKit's swipe-between-pages tracking) come too.
        guard let pTap = makeTap(at: .cghidEventTap, types: pointerTypes),
              let sTap = makeTap(at: .cgSessionEventTap, types: [.scrollWheel], rawTypes: [gestureEventType]) else {
            return false
        }
        pointerTap = pTap
        scrollTap = sTap

        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.idleCheck()
        }
        startStatsLogging()
        return true
    }

    private func makeTap(at location: CGEventTapLocation, types: [CGEventType], rawTypes: [UInt32] = []) -> CFMachPort? {
        let mask = (types.map(\.rawValue) + rawTypes).reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1) }
        guard let tap = CGEvent.tapCreate(tap: location, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: eventTapCallback, userInfo: nil)
        else { return nil }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return tap
    }

    private func refreshDisplays() {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        displayBounds = ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type.rawValue == gestureEventType {
            handleGesture(event)
            return Unmanaged.passUnretained(event)
        }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            for tap in [pointerTap, scrollTap].compactMap({ $0 }) where !CGEvent.tapIsEnabled(tap: tap) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        case .scrollWheel:
            handleScroll(event)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            handlePointer(event)
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Diagnostics

    struct Stats { var seen = 0, remapped = 0, skippedConfig = 0, skippedNotTrackpad = 0, scrollRemapped = 0 }
    private var stats = Stats()

    private func startStatsLogging() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.stats.seen > 0 || self.stats.scrollRemapped > 0 else { return }
            let s = self.stats
            let cfg = SettingsStore.engine.get()
            log.notice("pointer events: seen=\(s.seen, privacy: .public) remapped=\(s.remapped, privacy: .public) skippedConfig=\(s.skippedConfig, privacy: .public) skippedNotTrackpad=\(s.skippedNotTrackpad, privacy: .public) scrollRemapped=\(s.scrollRemapped, privacy: .public) enabled=\(cfg.enabled, privacy: .public) rotation=\(cfg.transform.rotation.rawValue, privacy: .public)")
            self.stats = Stats()
        }
    }

    // MARK: - Pointer

    /// Where we last put the cursor; the next move builds on it so the path stays exact.
    private var lastTarget: CGPoint?
    private var lastTargetTime: CFAbsoluteTime = 0
    private var pointerDirection = DirectionTracker()
    /// While true we've asked macOS to stop moving the cursor with the hardware.
    private var detached = false

    private func setDetached(_ value: Bool) {
        CGAssociateMouseAndMouseCursorPosition(value ? 0 : 1)
        detached = value
    }

    private func handlePointer(_ event: CGEvent) {
        let dx = event.getDoubleValueField(.mouseEventDeltaX)
        let dy = event.getDoubleValueField(.mouseEventDeltaY)

        let cfg = SettingsStore.engine.get()
        stats.seen += 1
        guard cfg.enabled, cfg.applyToPointer, !cfg.transform.isIdentity else {
            stats.skippedConfig += 1
            handBack(event, dx: dx, dy: dy)
            return
        }
        guard TouchMonitor.shared.isTargetActive(cfg.target) else {
            stats.skippedNotTrackpad += 1
            handBack(event, dx: dx, dy: dy)
            return
        }
        stats.remapped += 1
        guard dx != 0 || dy != 0 else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let fresh = lastTarget == nil || now - lastTargetTime > 0.3
        if fresh { pointerDirection.reset() }

        // Distance from macOS (keeps tracking speed and acceleration), direction from the finger.
        let finger = TouchMonitor.shared.consumeMotion(cfg.target)
        let speed = hypot(dx, dy) * cfg.pointerSpeed
        let mapped: (x: Double, y: Double)
        if let dir = pointerDirection.update(finger: finger, transform: cfg.transform) {
            mapped = (dir.x * speed, dir.y * speed)
        } else {
            mapped = (0, 0) // hold still until the direction is known
        }

        // event.location is where the HID system put the cursor; only trust it to start a move.
        let base = fresh ? CGPoint(x: event.location.x - dx, y: event.location.y - dy) : lastTarget!
        let target = clamp(CGPoint(x: base.x + mapped.x, y: base.y + mapped.y), from: base)
        lastTarget = target
        lastTargetTime = now

        setDetached(true)
        CGWarpMouseCursorPosition(target)
        event.location = target
        event.setDoubleValueField(.mouseEventDeltaX, value: mapped.x)
        event.setDoubleValueField(.mouseEventDeltaY, value: mapped.y)
    }

    /// A non-trackpad device moved: give the cursor back to the hardware.
    private func handBack(_ event: CGEvent, dx: Double, dy: Double) {
        lastTarget = nil
        pointerDirection.reset()
        guard detached else { return }
        // While detached the hardware didn't move the cursor, so apply this delta ourselves.
        let base = event.location
        let target = clamp(CGPoint(x: base.x + dx, y: base.y + dy), from: base)
        CGWarpMouseCursorPosition(target)
        event.location = target
        setDetached(false)
    }

    /// Reattach once the trackpad has gone idle.
    private func idleCheck() {
        guard detached else { return }
        if !TouchMonitor.shared.isTargetActive(SettingsStore.engine.get().target) { setDetached(false) }
    }

    private func clamp(_ p: CGPoint, from prev: CGPoint) -> CGPoint {
        if displayBounds.isEmpty || displayBounds.contains(where: { $0.contains(p) }) { return p }
        let r = displayBounds.first { $0.contains(prev) } ?? displayBounds[0]
        return CGPoint(x: min(max(p.x, r.minX), r.maxX - 1),
                       y: min(max(p.y, r.minY), r.maxY - 1))
    }

    // MARK: - Scroll

    /// Decided at the start of each scroll gesture and kept through its momentum phase.
    private var scrollTransforming = false
    private var scrollDirection = DirectionTracker()
    private var naturalScrolling = true
    /// What a unit of scroll magnitude becomes (direction × speed × natural-scrolling sign),
    /// shared with the companion gesture events. Nil until the direction is known.
    private var scrollVector: (x: Double, y: Double)?

    private func handleScroll(_ event: CGEvent) {
        let cfg = SettingsStore.engine.get()
        guard cfg.enabled, cfg.applyToScroll, !cfg.transform.isIdentity else {
            scrollTransforming = false
            return
        }
        // Trackpads send continuous (pixel) scrolling; classic wheels don't.
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 else { return }

        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        if phase == 1 || phase == 128 || (phase == 0 && momentum == 0) { // began / mayBegin / legacy
            scrollTransforming = TouchMonitor.shared.isTargetActive(cfg.target)
            scrollDirection.reset()
            scrollVector = nil
            _ = TouchMonitor.shared.consumeMotion(cfg.target) // drop motion from before the gesture
            naturalScrolling = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
        }
        guard scrollTransforming else { return }
        stats.scrollRemapped += 1

        // While fingers are down, keep following them; momentum keeps the last direction.
        let dir: (x: Double, y: Double)?
        if momentum == 0 {
            dir = scrollDirection.update(finger: TouchMonitor.shared.consumeMotion(cfg.target), transform: cfg.transform)
        } else {
            dir = scrollDirection.direction
        }

        // With natural scrolling the content follows the fingers; otherwise it's reversed.
        // Axis2 is horizontal, Axis1 vertical, both positive toward right/down finger travel.
        let sign = naturalScrolling ? 1.0 : -1.0
        scrollVector = dir.map { ($0.x * cfg.scrollSpeed * sign, $0.y * cfg.scrollSpeed * sign) }

        // Read every delta before writing any: setting the line delta also overwrites the
        // fixed-point and point deltas, so it has to be written first.
        let d = rewrite(Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)),
                        Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)))
        let f = rewrite(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2),
                        event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
        let p = rewrite(Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)),
                        Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(d.x.rounded()))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(d.y.rounded()))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: f.x)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: f.y)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(p.x.rounded()))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(p.y.rounded()))

        if momentum == 3 || phase == 8 { scrollTransforming = false } // momentum end / cancelled
    }

    /// Applies `scrollVector` to a delta; only the delta's magnitude is kept.
    private func rewrite(_ h: Double, _ v: Double) -> (x: Double, y: Double) {
        guard let vec = scrollVector else { return (0, 0) } // hold still until the direction is known
        let m = hypot(h, v)
        return (vec.x * m, vec.y * m)
    }

    /// Each trackpad scroll comes with a gesture event carrying the same motion in the pad's
    /// own axes. AppKit's swipe-between-pages tracking reads that one, so rewrite it the same way
    /// as the scroll; otherwise a sideways swipe looks vertical and never navigates.
    private func handleGesture(_ event: CGEvent) {
        guard event.getIntegerValueField(gestureHIDTypeField) == hidEventTypeScroll else { return }
        // The gesture's "began" reaches the session just before the scroll's, so start the
        // new gesture here rather than keep the previous one's direction.
        if event.getIntegerValueField(gesturePhaseField) == 1 {
            let cfg = SettingsStore.engine.get()
            scrollTransforming = cfg.enabled && cfg.applyToScroll && !cfg.transform.isIdentity
                && TouchMonitor.shared.isTargetActive(cfg.target)
            scrollVector = nil
        }
        guard scrollTransforming else { return }
        // Setting X and Y also updates the event's other copies of them (fields 113–117, 123, 139…).
        let g = rewrite(event.getDoubleValueField(gestureScrollXField),
                        event.getDoubleValueField(gestureScrollYField))
        event.setDoubleValueField(gestureScrollXField, value: g.x)
        event.setDoubleValueField(gestureScrollYField, value: g.y)
    }
}

// Undocumented gesture event (NSEventTypeGesture) and its fields.
private let gestureEventType: UInt32 = 29
private let gestureHIDTypeField = CGEventField(rawValue: 110)!
private let gestureScrollXField = CGEventField(rawValue: 118)!
private let gestureScrollYField = CGEventField(rawValue: 119)!
private let gesturePhaseField = CGEventField(rawValue: 132)!
private let hidEventTypeScroll: Int64 = 6

private func eventTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    EventTapController.shared.handle(type: type, event: event)
}
