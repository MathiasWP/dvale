/// Recognizes two complete, short, isolated Command taps. Never consumes input.
public struct CommandGesture {
    public var maximumHold: Double = 0.5
    public var maximumGap: Double = 0.5
    private var pressed: Int?
    private var pressedAt: Double = 0
    private var firstRelease: Double?

    public init() {}

    public mutating func reset() {
        pressed = nil
        firstRelease = nil
    }

    public mutating func command(key: Int, down: Bool, otherModifiers: Bool, at time: Double) -> Bool {
        guard !otherModifiers else { reset(); return false }
        if down {
            guard pressed == nil else { reset(); return false }
            if let firstRelease, time - firstRelease > maximumGap || time < firstRelease {
                self.firstRelease = nil
            }
            pressed = key
            pressedAt = time
            return false
        }
        guard pressed == key else { reset(); return false }
        pressed = nil
        guard time >= pressedAt, time - pressedAt <= maximumHold else {
            reset()
            return false
        }
        if let firstRelease, pressedAt - firstRelease <= maximumGap {
            self.firstRelease = nil
            return true
        }
        firstRelease = time
        return false
    }
}
