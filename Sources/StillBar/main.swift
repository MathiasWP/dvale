import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--shortcut-status"] {
    guard let report = ShortcutDiagnostics.queryRunningApp() else {
        fputs("No response from StillBar. Open the updated app from Applications first.\n", stderr)
        exit(1)
    }
    print(report)
    exit(0)
}
if arguments == ["--diagnose"] || arguments == ["--probe"] {
    do {
        let display = try DisplayControl()
        print("Touch Bar available: \(display.available)")
        print("DFR status: \(display.status); reports asleep: \(display.reportsDark)")
        print("Input Monitoring allowed for this diagnostic process: \(CGPreflightListenEventAccess())")
        print("For the running app's shortcut permission, use --shortcut-status.")
        if arguments == ["--probe"] {
            guard display.available else { exit(1) }
            let wasDark = display.reportsDark
            // Bounded manual hardware check; restore the original reported state.
            var restored = false
            defer {
                if !wasDark && !restored { _ = display.request(on: true) }
            }
            let accepted = display.request(on: false)
            Thread.sleep(forTimeInterval: 0.4)
            print("Immediate off request accepted: \(accepted)")
            print("After off: status=\(display.status), reports asleep=\(display.reportsDark)")
            if !wasDark {
                restored = display.request(on: true)
                Thread.sleep(forTimeInterval: 0.7)
                print("Restoration accepted: \(restored); status=\(display.status)")
            }
        }
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
    exit(0)
}

let delegate = AppDelegate()
if arguments.count == 2 && arguments[0] == "--snapshot" {
    delegate.snapshotPath = arguments[1]
} else if !arguments.isEmpty {
    fputs("Usage: StillBar [--diagnose | --probe | --shortcut-status | --snapshot path.png]\n", stderr)
    exit(64)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
