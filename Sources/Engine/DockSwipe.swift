import CoreGraphics
import os

private let log = Logger(subsystem: "local.trackpadrotator", category: "dock")

/// Three- and four-finger swipes (Mission Control, App Exposé, switching full-screen apps).
///
/// macOS recognises them on the pad's own axes and sends the Dock a "dock swipe" event saying
/// which axis and how far. Turning that into your frame makes each swipe go the way you moved;
/// what it then does is still up to System Settings → Trackpad → More Gestures.
final class DockSwipeRewriter {
    /// Decided when each swipe begins and kept until it ends.
    private var transforming = false

    func handle(_ event: CGEvent) {
        let motion = event.getIntegerValueField(Field.motion)
        let phase = event.getIntegerValueField(Field.phase)
        let cfg = SettingsRepository.engine.get()

        if phase == 1 { // began
            transforming = cfg.enabled && cfg.dockSwipes && !cfg.transform.isIdentity
                && TouchMonitor.shared.isTargetActive(cfg.target, within: 0.5)
            log.debug("dock swipe began: motion=\(motion, privacy: .public) fingers=\(event.getIntegerValueField(Field.fingers), privacy: .public) transforming=\(self.transforming, privacy: .public) hid=\(AttachedHIDEvent.dockSwipeDescription(of: event), privacy: .public)")
        }
        guard transforming, motion == Motion.horizontal || motion == Motion.vertical else { return }

        // Progress runs along the motion axis: positive is right, or up (the direction mask agrees).
        let progress = event.getDoubleValueField(Field.progress)
        let along = motion == Motion.horizontal ? (x: 1.0, y: 0.0) : (x: 0.0, y: -1.0) // pad frame, +y down
        let t = cfg.transform.apply(along.x, along.y)
        let newMotion = abs(t.x) >= abs(t.y) ? Motion.horizontal : Motion.vertical
        let sense = newMotion == Motion.horizontal ? (t.x < 0 ? -1.0 : 1.0) : (t.y > 0 ? -1.0 : 1.0)

        event.setIntegerValueField(Field.motion, value: newMotion)
        event.setDoubleValueField(Field.progress, value: progress * sense)
        for f in [Field.velocityX, Field.velocityY] {
            event.setDoubleValueField(f, value: event.getDoubleValueField(f) * sense)
        }
        // Position deltas are +y down.
        let p = cfg.transform.apply(event.getDoubleValueField(Field.positionX), event.getDoubleValueField(Field.positionY))
        event.setDoubleValueField(Field.positionX, value: p.x)
        event.setDoubleValueField(Field.positionY, value: p.y)
        let mask = event.getIntegerValueField(Field.mask)
        let newMask = Self.turn(mask: mask, cfg.transform)
        if mask != 0 { event.setIntegerValueField(Field.mask, value: newMask) }

        AttachedHIDEvent.rewriteDockSwipe(of: event, expecting: (motion, progress), motion: newMotion,
                                          sense: sense, mask: newMask, transform: cfg.transform)
    }

    /// Swipe direction bits: up 1, down 2, left 4, right 8.
    private static func turn(mask: Int64, _ transform: AxisTransform) -> Int64 {
        let dirs: [(bit: Int64, v: (x: Double, y: Double))] = [(1, (0, -1)), (2, (0, 1)), (4, (-1, 0)), (8, (1, 0))]
        var out: Int64 = 0
        for d in dirs where mask & d.bit != 0 {
            let t = transform.apply(d.v.x, d.v.y)
            out |= dirs.first { abs($0.v.x - t.x) < 0.5 && abs($0.v.y - t.y) < 0.5 }?.bit ?? 0
        }
        return out | (mask & ~0xF)
    }

    private enum Motion {
        static let horizontal: Int64 = 1
        static let vertical: Int64 = 2
    }

    /// Undocumented dock swipe event fields. Setting one also updates its copies (165, 135, 117/164).
    private enum Field {
        static let mask = CGEventField(rawValue: 115)!
        static let motion = CGEventField(rawValue: 123)!
        static let progress = CGEventField(rawValue: 124)!
        static let positionX = CGEventField(rawValue: 125)!
        static let positionY = CGEventField(rawValue: 126)!
        static let velocityX = CGEventField(rawValue: 129)!
        static let velocityY = CGEventField(rawValue: 130)!
        static let phase = CGEventField(rawValue: 132)!
        static let fingers = CGEventField(rawValue: 138)!
    }
}
