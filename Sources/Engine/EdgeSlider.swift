import AppKit

/// Recognises "one finger slides up or down along your left or right edge": brightness on the
/// left, volume on the right. Each step is one press of the matching media key, so macOS shows
/// its own volume and brightness HUD, and a haptic tick.
struct EdgeSliderTracker {
    enum Control { case brightness, volume }

    /// The control being adjusted; pointer movement is held back while this is set.
    private(set) var active: Control?
    private var candidate: Control?
    private var finger: Int32?
    private var start: (x: Double, y: Double)?
    private var anchor = 0.0

    private let edgeZone = 8.0  // mm from your left or right edge where the finger has to land
    private let decideAfter = 3.0 // mm of travel before it's known whether this is a slide
    private let stepLength = 5.0 // mm of travel per volume or brightness step

    /// Feed every touch frame. Returns the control and how many steps to move it
    /// (positive is up), or nil. `transform` maps pad vectors to your frame.
    mutating func update(touching: [TouchPoint], widthMM: Double, heightMM: Double,
                         transform: AxisTransform) -> (Control, Int)? {
        // One finger only; a second finger or a new finger starts over.
        guard touching.count == 1, widthMM > 0, heightMM > 0,
              finger == nil || finger == touching[0].id else {
            self = EdgeSliderTracker()
            return nil
        }
        let t = touching[0]
        let p = transform.apply((Double(t.x) - 0.5) * widthMM, (0.5 - Double(t.y)) * heightMM)

        guard let start else {
            // Half of the pad's width as you see it: its own width or height, depending on the turn.
            let halfWidth = (abs(transform.apply(widthMM, 0).x) + abs(transform.apply(0, heightMM).x)) / 2
            finger = t.id
            self.start = p
            if p.x < -halfWidth + edgeZone { candidate = .brightness }
            if p.x > halfWidth - edgeZone { candidate = .volume }
            return nil
        }
        guard let candidate else { return nil }

        guard let active else {
            let dx = p.x - start.x, dy = p.y - start.y
            guard hypot(dx, dy) >= decideAfter else { return nil }
            if abs(dy) > 2 * abs(dx) {
                self.active = candidate
                anchor = p.y
            } else {
                self.candidate = nil // a sideways move: an ordinary pointer move from the edge
            }
            return nil
        }
        // +y is down in your frame, so up is negative travel.
        let steps = Int((anchor - p.y) / stepLength)
        guard steps != 0 else { return nil }
        anchor -= Double(steps) * stepLength
        return (active, steps)
    }
}

/// Presses the volume and brightness keys, as the keyboard would.
enum MediaKeys {
    // NX_KEYTYPE_* from IOKit's ev_keymap.h.
    private static let soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3

    static func adjust(_ control: EdgeSliderTracker.Control, steps: Int) {
        let key = switch control {
        case .volume: steps > 0 ? soundUp : soundDown
        case .brightness: steps > 0 ? brightnessUp : brightnessDown
        }
        for _ in 0..<abs(steps) {
            post(key, down: true)
            post(key, down: false)
        }
        // A tick on Force Touch trackpads, so each step can be felt.
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private static func post(_ key: Int, down: Bool) {
        let state = down ? 0xA : 0xB
        let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                       modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                                       timestamp: 0, windowNumber: 0, context: nil,
                                       subtype: 8, data1: (key << 16) | (state << 8), data2: -1)
        event?.cgEvent?.post(tap: .cghidEventTap)
    }
}
