import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private let toggleItem = NSMenuItem(title: "Turn Touch Bar Off", action: #selector(toggle), keyEquivalent: "")
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    var snapshotPath: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "local.stillbar.app")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if snapshotPath == nil, let other = others.first {
            other.activate(options: [.activateIgnoringOtherApps])
            NSApp.terminate(nil)
            return
        }
        model = AppModel(preview: snapshotPath != nil)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.autoenablesItems = false
        stateItem.isEnabled = false
        menu.delegate = self
        menu.addItem(stateItem)
        menu.addItem(.separator())
        toggleItem.target = self
        menu.addItem(toggleItem)
        let settings = NSMenuItem(title: "Open dvale…", action: #selector(showWindow), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit & Restore Touch Bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
        model.didChange = { [weak self] in self?.updateMenu() }
        updateMenu()
        if snapshotPath != nil || !UserDefaults.standard.bool(forKey: "hasLaunched") {
            showWindow()
        }
        if snapshotPath == nil { UserDefaults.standard.set(true, forKey: "hasLaunched") }
        if let snapshotPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let view = self?.window?.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
                do { try png.write(to: URL(fileURLWithPath: snapshotPath)) }
                catch { fputs("\(error)\n", stderr); exit(1) }
                NSApp.terminate(nil)
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) { model.refresh() }

    private func updateMenu() {
        statusItem.button?.image = NSImage(systemSymbolName: model.keepOff ? "moon.zzz.fill" : "moon", accessibilityDescription: "dvale")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = model.keepOff ? "dvale · Keep Off enabled" : "dvale · macOS control"
        toggleItem.title = model.keepOff ? "Turn Touch Bar On" : "Turn Touch Bar Off"
        toggleItem.isEnabled = model.available
        stateItem.title = !model.available ? "Touch Bar unavailable" : model.reportsDark ? "macOS reports display asleep" : "macOS reports display awake"
    }

    @objc private func toggle() { model.toggle() }

    @objc private func showWindow() {
        if window == nil {
            let view = NSHostingView(rootView: ControlView(model: model))
            let size = view.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "dvale"
            window.isReleasedWhenClosed = false
            window.contentView = view
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model != nil { showWindow() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}
