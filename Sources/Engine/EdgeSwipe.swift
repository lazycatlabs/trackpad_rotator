import AppKit
import ApplicationServices
import os

private let log = Logger(subsystem: "local.trackpadrotator", category: "edge")

/// Recognises "swipe left from the right edge with two fingers" (Notification Center) in your frame.
///
/// macOS looks for it on the pad's own right edge, which is no longer your right edge once
/// the pad is turned, so the system gesture never fires and the swipe arrives as a scroll.
struct EdgeSwipeTracker {
    /// Fingers came down at your right edge; their scrolling is held back.
    private(set) var active = false
    private var fired = false
    private var downAt: CFAbsoluteTime?
    private var start: (x: Double, y: Double)?

    private let edgeZone = 5.0      // mm from your right edge where the swipe has to start
    private let landingWindow = 0.2 // s after the first finger lands that the edge is checked
    private let travelNeeded = 8.0  // mm of leftward travel before it fires

    /// Feed every touch frame. Returns true once per swipe, when it's recognised.
    /// `widthMM`/`heightMM` are the pad's own size; `transform` maps pad vectors to your frame.
    mutating func update(touching: [TouchPoint], widthMM: Double, heightMM: Double,
                         transform: AxisTransform, now: CFAbsoluteTime) -> Bool {
        guard !touching.isEmpty, widthMM > 0, heightMM > 0 else {
            self = EdgeSwipeTracker()
            return false
        }
        let downAt = self.downAt ?? now
        self.downAt = downAt

        // Finger positions in mm from the pad's centre, turned into your frame.
        let points = touching.map {
            transform.apply((Double($0.x) - 0.5) * widthMM, (0.5 - Double($0.y)) * heightMM)
        }
        // Half of the pad's width as you see it: its own width or height, depending on the turn.
        let halfWidth = (abs(transform.apply(widthMM, 0).x) + abs(transform.apply(0, heightMM).x)) / 2

        if !active, now - downAt < landingWindow, points.contains(where: { $0.x > halfWidth - edgeZone }) {
            active = true
        }
        guard active, !fired else { return false }
        guard points.count == 2 else {
            start = nil // re-anchor once exactly two fingers are down
            return false
        }

        let c = (x: (points[0].x + points[1].x) / 2, y: (points[0].y + points[1].y) / 2)
        guard let start else {
            self.start = c
            return false
        }
        let dx = c.x - start.x, dy = c.y - start.y
        if dx < -travelNeeded, abs(dx) > 2 * abs(dy) {
            fired = true
            return true
        }
        return false
    }
}

enum NotificationCenterUI {
    /// Opens Notification Center, as the system edge swipe would.
    static func open() {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.notificationcenterui" }) else {
            log.error("Notification Center process not found")
            return
        }
        // Whether it's already open can't be told: its window stays listed (even on screen)
        // after it closes. It reports kAXErrorActionUnsupported even though it works.
        AXUIElementPerformAction(AXUIElementCreateApplication(app.processIdentifier), "AXToggleUI" as CFString)
    }
}
