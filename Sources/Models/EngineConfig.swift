import Foundation

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
    /// Turn the gesture data swipe between pages reads, so sideways swipes go back/forward.
    var swipeNavigation = true
    /// Open Notification Center when two fingers swipe left from your right edge.
    var notificationCenterSwipe = true
    /// Turn three- and four-finger swipes; System Settings still decides what they do.
    var dockSwipes = true
    var target: DeviceTarget = .externalTrackpads
    /// Multipliers on top of macOS's own tracking/scroll speed.
    var pointerSpeed = 1.0
    var scrollSpeed = 1.0
}
