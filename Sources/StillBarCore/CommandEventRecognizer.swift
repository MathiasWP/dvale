import CoreGraphics

/// Decode the flags captured with the event. Querying the live keyboard state
/// here can mistake a queued press for a release after a fast tap is finished.
public struct CommandEventRecognizer {
    private var gesture = CommandGesture()

    public init(doubleTapInterval: Double = 0.5) {
        gesture.maximumGap = min(max(doubleTapInterval, 0.25), 1)
    }

    public mutating func reset() { gesture.reset() }

    public mutating func receive(type: CGEventType, keyCode: Int, flags: CGEventFlags, timestamp: Double) -> Bool {
        guard type == .flagsChanged, keyCode == 54 || keyCode == 55 else {
            gesture.reset()
            return false
        }
        // NX_DEVICELCMDKEYMASK / NX_DEVICERCMDKEYMASK from IOLLEvent.h.
        let left: UInt64 = 0x8
        let right: UInt64 = 0x10
        let own = keyCode == 55 ? left : right
        let other = keyCode == 55 ? right : left
        let hasDeviceFlags = flags.rawValue & (left | right) != 0
        // Some keyboards/remappers only supply the aggregate Command flag.
        let down = hasDeviceFlags ? flags.rawValue & own != 0 : flags.contains(.maskCommand)
        let otherDown = flags.rawValue & other != 0
        let disallowed: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskSecondaryFn, .maskHelp]
        return gesture.command(key: keyCode, down: down,
                               otherModifiers: otherDown || !flags.intersection(disallowed).isEmpty,
                               at: timestamp)
    }
}
