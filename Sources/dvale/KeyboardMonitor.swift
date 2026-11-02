import AppKit
import Carbon
import DvaleCore

final class KeyboardMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var recognizer = CommandEventRecognizer(doubleTapInterval: NSEvent.doubleClickInterval)
    private(set) var commandEvents = 0
    private(set) var toggles = 0
    private(set) var lastCommandAt: Date?
    var onToggle: (() -> Void)?
    var onCommand: (() -> Void)?
    var active: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }
    var permissionGranted: Bool { CGPreflightListenEventAccess() || AXIsProcessTrusted() }
    var secureInput: Bool { IsSecureEventInputEnabled() }

    var diagnostics: [String: Any] {
        ["pid": ProcessInfo.processInfo.processIdentifier,
         "appPath": Bundle.main.bundlePath,
         "inputMonitoringAllowed": CGPreflightListenEventAccess(),
         "accessibilityAllowed": AXIsProcessTrusted(),
         "eventTapActive": active,
         "secureKeyboardInput": secureInput,
         "commandEventsReceived": commandEvents,
         "doubleTapsRecognized": toggles,
         "lastCommandReceived": lastCommandAt.map { ISO8601DateFormatter().string(from: $0) } ?? "none"]
    }

    @discardableResult func start() -> Bool {
        if active { return true }
        stop()
        guard permissionGranted else { return false }
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.receive(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .listenOnly, eventsOfInterest: mask, callback: callback,
                                         userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            recognizer.reset()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let isCommand = type == .flagsChanged && (key == 54 || key == 55)
        if isCommand {
            commandEvents += 1
            lastCommandAt = Date()
        }
        if recognizer.receive(type: type, keyCode: key, flags: event.flags,
                              timestamp: Double(event.timestamp) / 1_000_000_000) {
            toggles += 1
            onToggle?()
        }
        if isCommand { onCommand?() }
    }

    func reset() { recognizer.reset() }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        recognizer.reset()
    }

    deinit { stop() }
}
