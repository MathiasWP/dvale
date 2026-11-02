/// Owns intent and cancellation independently of the undocumented hardware API.
public struct OffPolicy {
    public private(set) var keepOff = false
    public private(set) var sleeping = false
    public private(set) var generation: UInt64 = 0
    private var lastAttempt: Double = -.infinity

    public init() {}

    public mutating func select(off: Bool) {
        keepOff = off
        generation &+= 1
        lastAttempt = -.infinity
    }

    public mutating func setSleeping(_ value: Bool) {
        sleeping = value
        generation &+= 1
        lastAttempt = -.infinity
    }

    /// A token prevents old wake retries from undoing a later On decision.
    public mutating func shouldRequestOff(dark: Bool, now: Double, token: UInt64? = nil, force: Bool = false) -> Bool {
        guard keepOff, !sleeping, token == nil || token == generation else { return false }
        guard force || !dark else { return false }
        guard now - lastAttempt >= 0.1 else { return false }
        lastAttempt = now
        return true
    }
}
