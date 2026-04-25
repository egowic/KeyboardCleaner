import SwiftUI
import AppKit
import ServiceManagement

// CGEventType 14 = NX_SYSDEFINED (media keys: volume, brightness, play/pause…)
private let kCGEventNXSysDefined: CGEventType = CGEventType(rawValue: 14)!

// MARK: - App Entry Point

@main
struct KeyboardCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - Lock Overlay View

struct LockOverlayView: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(.white)

            VStack(spacing: 6) {
                Text("Keyboard Locked")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("Trackpad is active")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Button(action: onUnlock) {
                Text("Unlock")
                    .font(.body.weight(.medium))
                    .frame(width: 120)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.25))
            .controlSize(.large)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: State
    private var statusItem: NSStatusItem?
    private var isLocked = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var overlayPanel: NSPanel?

    // MARK: Menu item references
    private var lockMenuItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = menuBarImage(locked: false)

        buildMenu()
        checkAccessibilityOnLaunch()
    }

    // MARK: - Menu Bar Icon

    private func menuBarImage(locked: Bool) -> NSImage {
        // Her iki state de keyboard + kilit rozeti — açık veya kapalı
        let lockSymbol = locked ? "lock.fill" : "lock.open.fill"
        let size = NSSize(width: 26, height: 16)
        let composite = NSImage(size: size, flipped: false) { _ in
            let kbConf = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            if let kb = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)?
                .withSymbolConfiguration(kbConf) {
                kb.draw(in: NSRect(x: 0, y: 3, width: 19, height: 12))
            }
            let lockConf = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            if let lock = NSImage(systemSymbolName: lockSymbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(lockConf) {
                lock.draw(in: NSRect(x: 17, y: 0, width: 9, height: 10))
            }
            return true
        }
        composite.isTemplate = true
        return composite
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isLocked { performUnlock() }
    }

    // MARK: Accessibility

    private func checkAccessibilityOnLaunch() {
        // prompt:true → macOS shows its own dialog AND registers the app in the Accessibility list
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        NSLog("KeyboardCleaner: launch trusted=\(trusted)")
    }

    private func showRestartAlert() {
        let alert = NSAlert()
        alert.messageText = "Almost there — please restart KeyboardCleaner"
        alert.informativeText = "You've granted Accessibility access, but KeyboardCleaner needs to be relaunched for the permission to take effect.\n\nClick Quit & Relaunch below."
        alert.addButton(withTitle: "Quit & Relaunch")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            relaunchApp()
        }
    }

    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func showAccessibilityNeededAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "KeyboardCleaner needs Accessibility access to lock keyboard input.\n\nOpen System Settings → Privacy & Security → Accessibility and enable KeyboardCleaner, then relaunch the app."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            // Trigger registration in Accessibility list
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }

    // MARK: Menu

    private func buildMenu() {
        let menu = NSMenu()

        let lockItem = NSMenuItem(title: "Lock Keyboard", action: #selector(toggleLock), keyEquivalent: "")
        lockItem.target = self
        menu.addItem(lockItem)
        self.lockMenuItem = lockItem

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)
        self.launchAtLoginItem = loginItem

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit KeyboardCleaner", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func refreshMenuState() {
        lockMenuItem?.title = isLocked ? "Unlock Keyboard" : "Lock Keyboard"
    }

    // MARK: Lock / Unlock

    @objc private func toggleLock() {
        isLocked ? performUnlock() : performLock()
        refreshMenuState()
    }

    private func performLock() {
        guard !isLocked else { return }

        let trusted = AXIsProcessTrusted()
        NSLog("KeyboardCleaner: performLock trusted=\(trusted)")

        guard trusted else {
            showAccessibilityNeededAlert()
            return
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)      |
            (1 << CGEventType.keyUp.rawValue)        |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << kCGEventNXSysDefined.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, _, _ -> Unmanaged<CGEvent>? in nil },
            userInfo: nil
        )

        guard let tap else {
            // tapCreate can fail even when AXIsProcessTrusted returns true if
            // the permission was granted while the process was already running.
            NSLog("KeyboardCleaner: tapCreate returned nil despite trusted")
            showRestartAlert()
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            NSLog("KeyboardCleaner: failed to create runloop source")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        self.isLocked = true
        statusItem?.button?.image = menuBarImage(locked: true)
        playSound(named: "Submarine")
        showOverlay()
    }

    private func performUnlock() {
        guard isLocked else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isLocked = false
        statusItem?.button?.image = menuBarImage(locked: false)
        playSound(named: "Glass")
        hideOverlay()
    }

    // MARK: Overlay

    private func showOverlay() {
        let size = NSSize(width: 320, height: 260)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false   // başka uygulamaya geçince kaybolmasın
        panel.level = NSWindow.Level.statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = false

        let overlayView = LockOverlayView { [weak self] in
            guard let self else { return }
            self.performUnlock()
            self.refreshMenuState()
        }

        let hosting = NSHostingView(rootView: overlayView)
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting
        panel.center()
        panel.orderFrontRegardless()

        self.overlayPanel = panel
    }

    private func hideOverlay() {
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
    }

    // MARK: Launch at Login

    private var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc private func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLoginEnabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
                launchAtLoginItem?.state = launchAtLoginEnabled ? .on : .off
            } catch { }
        }
    }

    // MARK: Sound

    private func playSound(named name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }

    // MARK: Quit

    @objc private func quitApp() {
        if isLocked { performUnlock() }
        NSApp.terminate(nil)
    }
}
