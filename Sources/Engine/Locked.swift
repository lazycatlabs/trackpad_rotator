import Foundation

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
