import CoreGraphics
import Foundation

/// The IOHIDEvent a CGEvent carries from the device. AppKit's swipe-between-pages tracking reads
/// its scroll values rather than the CGEvent's fields, so those have to be rewritten too.
/// All of this is private API, looked up at runtime; when it's missing the rewrite is skipped.
enum AttachedHIDEvent {
    private typealias Ref = AnyObject
    private static let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)
    private static let skylight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static let copyEvent = load(skylight, "SLEventCopyIOHIDEvent",
                                        as: (@convention(c) (CGEvent) -> Unmanaged<Ref>?).self)
    private static let setEvent = load(skylight, "SLEventSetIOHIDEvent",
                                       as: (@convention(c) (CGEvent, Ref) -> Void).self)
    private static let getType = load(iokit, "IOHIDEventGetType",
                                      as: (@convention(c) (Ref) -> UInt32).self)
    private static let getFloat = load(iokit, "IOHIDEventGetFloatValue",
                                       as: (@convention(c) (Ref, UInt32) -> Double).self)
    private static let setFloat = load(iokit, "IOHIDEventSetFloatValue",
                                       as: (@convention(c) (Ref, UInt32, Double) -> Void).self)
    private static let getChildren = load(iokit, "IOHIDEventGetChildren",
                                          as: (@convention(c) (Ref) -> Unmanaged<CFArray>?).self)

    private static func load<T>(_ lib: UnsafeMutableRawPointer?, _ name: String, as: T.Type) -> T? {
        guard let sym = dlsym(lib, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    private static let typeScroll: UInt32 = 6
    private static let fieldScrollX: UInt32 = typeScroll << 16
    private static let fieldScrollY: UInt32 = typeScroll << 16 | 1

    /// Applies `transform` to the scroll values of the attached event and its children.
    /// Returns false when there was nothing to rewrite.
    @discardableResult
    static func rewriteScroll(of event: CGEvent,
                              _ transform: (_ x: Double, _ y: Double) -> (x: Double, y: Double)) -> Bool {
        guard let copyEvent, let setEvent, let getType, let getFloat, let setFloat, let getChildren,
              let hid = copyEvent(event)?.takeRetainedValue() else { return false }
        var events = [hid]
        if let children = getChildren(hid)?.takeUnretainedValue() as? [Ref] { events += children }
        var changed = false
        for e in events where getType(e) == typeScroll {
            let t = transform(getFloat(e, fieldScrollX), getFloat(e, fieldScrollY))
            setFloat(e, fieldScrollX, t.x)
            setFloat(e, fieldScrollY, t.y)
            changed = true
        }
        if changed { setEvent(event, hid) }
        return changed
    }

    private static let typeVelocity: UInt32 = 9
    private static let typeDigitizer: UInt32 = 11

    /// Turns the finger positions (digitizer events, 0…1 with +y down, about the pad's centre)
    /// and velocities in the attached event and its descendants. Returns false when there were none.
    @discardableResult
    static func rewriteTouches(of event: CGEvent, _ transform: AxisTransform) -> Bool {
        guard let copyEvent, let setEvent, let getType, let getFloat, let setFloat, let getChildren,
              let hid = copyEvent(event)?.takeRetainedValue() else { return false }
        var changed = false
        func visit(_ e: Ref, depth: Int) {
            switch getType(e) {
            case typeDigitizer:
                let fx = typeDigitizer << 16, fy = typeDigitizer << 16 | 1
                let t = transform.apply(getFloat(e, fx) - 0.5, getFloat(e, fy) - 0.5)
                setFloat(e, fx, t.x + 0.5)
                setFloat(e, fy, t.y + 0.5)
                changed = true
            case typeVelocity:
                let fx = typeVelocity << 16, fy = typeVelocity << 16 | 1
                let t = transform.apply(getFloat(e, fx), getFloat(e, fy))
                setFloat(e, fx, t.x)
                setFloat(e, fy, t.y)
                changed = true
            default:
                break
            }
            guard depth < 3, let children = getChildren(e)?.takeUnretainedValue() as? [Ref] else { return }
            for child in children { visit(child, depth: depth + 1) }
        }
        visit(hid, depth: 0)
        if changed { setEvent(event, hid) }
        return changed
    }

    /// Scroll values of the attached event, for diagnostics.
    static func scroll(of event: CGEvent) -> (x: Double, y: Double)? {
        guard let copyEvent, let getType, let getFloat,
              let hid = copyEvent(event)?.takeRetainedValue(), getType(hid) == typeScroll else { return nil }
        return (getFloat(hid, fieldScrollX), getFloat(hid, fieldScrollY))
    }
}
