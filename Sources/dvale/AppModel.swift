import AppKit
import SwiftUI
import ServiceManagement
import DvaleCore

final class AppModel: ObservableObject {
    @Published private(set) var keepOff = false
    @Published private(set) var reportsDark = false
    @Published private(set) var available = false
    @Published private(set) var shortcutActive = false
    @Published private(set) var shortcutMessage = "Allow Input Monitoring to enable the shortcut"
    @Published private(set) var launchAtLogin = false
    @Published private(set) var competingApp = false
    @Published private(set) var error: String?
    var didChange: (() -> Void)?

    private var display: DisplayControl?
    private let keyboard = KeyboardMonitor()
    private var policy = OffPolicy()
    private var timer: Timer?
    private var ownsOffRequest = false
    private var observers: [NSObjectProtocol] = []
    private var diagnosticsObserver: NSObjectProtocol?
    private let preview: Bool

    init(preview: Bool = false) {
        self.preview = preview
        do { display = try DisplayControl() }
        catch { self.error = error.localizedDescription }
        refresh()
        guard !preview else { return }
        display?.observe { [weak self] in self?.enforce(); self?.refresh() }
        startKeyboardMonitor()
        observeWorkspace()
        startTimer()
        if UserDefaults.standard.bool(forKey: "keepOff") { setOff(true) }
    }

    private func startKeyboardMonitor() {
        keyboard.onToggle = { [weak self] in self?.toggle() }
        keyboard.onCommand = { [weak self] in self?.refreshShortcutStatus() }
        shortcutActive = keyboard.start()
        diagnosticsObserver = ShortcutDiagnostics.respond { [weak self] in self?.keyboard.diagnostics }
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.policy.keepOff { _ = self.display?.request(on: false) }
            self.policy.setSleeping(true)
            self.keyboard.reset()
        })
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.resume()
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.keyboard.reset()
        })
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, !self.policy.sleeping else { return }
            self.enforce()
            if !self.keyboard.active { self.shortcutActive = self.keyboard.start() }
            self.refresh()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func toggle() { setOff(!keepOff) }

    func setOff(_ off: Bool) {
        guard !preview, let display, display.available else { return }
        error = nil
        policy.select(off: off)
        keepOff = off
        if off {
            let accepted = display.request(on: false)
            if accepted {
                ownsOffRequest = true
                UserDefaults.standard.set(true, forKey: "keepOff")
                scheduleRetries()
            } else {
                policy.select(off: false)
                keepOff = false
                UserDefaults.standard.set(false, forKey: "keepOff")
                error = "macOS refused the off request. Try again after quitting other Touch Bar utilities."
            }
        } else {
            UserDefaults.standard.set(false, forKey: "keepOff")
            if display.request(on: true) { ownsOffRequest = false }
            else { error = "macOS refused the on request. Use Turn On again, or quit dvale to retry restoration." }
        }
        refresh()
    }

    private func enforce(force: Bool = false, token: UInt64? = nil) {
        guard let display, display.available,
              policy.shouldRequestOff(dark: display.reportsDark, now: ProcessInfo.processInfo.systemUptime,
                                      token: token, force: force) else { return }
        if display.request(on: false) {
            ownsOffRequest = true
            error = nil
        } else {
            error = "macOS refused an off request. dvale will retry while Keep Off is enabled."
        }
    }

    private func resume() {
        keyboard.reset()
        policy.setSleeping(false)
        enforce(force: true)
        scheduleRetries()
        refresh()
    }

    private func scheduleRetries() {
        let token = policy.generation
        // Bounded retries cover service startup after wake. Later checks only write
        // when macOS reports awake; they never perform an automatic on/off cycle.
        for delay in [0.15, 0.4, 1.0, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.enforce(force: true, token: token)
                self?.refresh()
            }
        }
    }

    func refresh() {
        available = display?.available ?? false
        reportsDark = display?.reportsDark ?? false
        competingApp = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.clemstation.Touch-Bar-Control" }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        refreshShortcutStatus()
        didChange?()
    }

    private func refreshShortcutStatus() {
        shortcutActive = keyboard.active
        if keyboard.secureInput {
            shortcutMessage = "Paused by secure keyboard input · leave password fields to retry"
        } else if !shortcutActive {
            shortcutMessage = keyboard.permissionGranted
                ? "Permission is allowed, but the listener could not start · relaunch dvale"
                : "Allow Input Monitoring to enable the shortcut"
        } else if keyboard.commandEvents > 0 {
            shortcutMessage = "Command received · \(keyboard.toggles) double-taps detected"
        } else {
            shortcutMessage = "Listening · tap Command twice to test"
        }
    }

    func enableShortcut() {
        _ = CGRequestListenEventAccess()
        shortcutActive = keyboard.start()
        if !shortcutActive,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { self.error = "Login setting: \(error.localizedDescription)" }
        refresh()
    }

    func shutdown() {
        timer?.invalidate()
        policy.select(off: false)
        keyboard.stop()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        if let diagnosticsObserver { DistributedNotificationCenter.default().removeObserver(diagnosticsObserver) }
        if ownsOffRequest { _ = display?.request(on: true) }
    }
}
