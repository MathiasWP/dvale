import AppKit
import ObjectiveC

enum DisplayError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self { case .unavailable(let reason): return reason }
    }
}

/// Private APIs are loaded at runtime so missing support produces a useful error.
/// A successful request / dark status is not proof of physical power isolation.
final class DisplayControl {
    private let clientClass: NSObject.Type
    private let statusFunction: @convention(c) () -> UInt32
    private let registerFunction: @convention(c) (@convention(block) (UInt32) -> Void) -> Void
    private var retainedCallback: (@convention(block) (UInt32) -> Void)?
    private let offSelector = NSSelectorFromString("turnOffWithPeriod:")
    private let onSelector = NSSelectorFromString("turnOn")

    init() throws {
        guard dlopen("/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness", RTLD_NOW) != nil,
              let foundation = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW),
              let cls = NSClassFromString("DFRBrightnessClient") as? NSObject.Type,
              let status = dlsym(foundation, "DFRGetStatus"),
              let register = dlsym(foundation, "DFRRegisterStatusChangeCallback") else {
            throw DisplayError.unavailable("This macOS version does not expose the required Touch Bar controls.")
        }
        // Verified locally: BOOL turnOffWithPeriod:(float), BOOL turnOn.
        // Check signatures before calling through a C function pointer.
        guard Self.validMethod(cls, selector: offSelector, arguments: 3, parameter: "f"),
              Self.validMethod(cls, selector: onSelector, arguments: 2, parameter: nil) else {
            throw DisplayError.unavailable("The Touch Bar API has changed. StillBar cannot safely use it.")
        }
        clientClass = cls
        statusFunction = unsafeBitCast(status, to: (@convention(c) () -> UInt32).self)
        registerFunction = unsafeBitCast(register, to: (@convention(c) (@convention(block) (UInt32) -> Void) -> Void).self)
    }

    private static func validMethod(_ cls: AnyClass, selector: Selector, arguments: UInt32, parameter: String?) -> Bool {
        guard let method = class_getInstanceMethod(cls, selector), method_getNumberOfArguments(method) == arguments else { return false }
        let returnType = method_copyReturnType(method)
        defer { free(returnType) }
        guard ["B", "c"].contains(String(cString: returnType)) else { return false }
        if let parameter {
            guard let type = method_copyArgumentType(method, 2) else { return false }
            defer { free(type) }
            return String(cString: type) == parameter
        }
        return true
    }

    var status: UInt32 { statusFunction() }
    var available: Bool { status & 0x1 != 0 }
    var reportsDark: Bool { available && status & 0x4 != 0 }

    func observe(_ handler: @escaping () -> Void) {
        let callback: @convention(block) (UInt32) -> Void = { _ in
            DispatchQueue.main.async(execute: handler)
        }
        retainedCallback = callback
        registerFunction(callback)
    }

    func request(on: Bool) -> Bool {
        guard available else { return false }
        // Fresh clients avoid trusting the state cached by an earlier request.
        let client = clientClass.init()
        if on {
            typealias Call = @convention(c) (AnyObject, Selector) -> Bool
            let call = unsafeBitCast(client.method(for: onSelector), to: Call.self)
            return call(client, onSelector)
        }
        typealias Call = @convention(c) (AnyObject, Selector, Float) -> Bool
        let call = unsafeBitCast(client.method(for: offSelector), to: Call.self)
        return call(client, offSelector, 0)
    }
}
