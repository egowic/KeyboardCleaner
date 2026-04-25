import SwiftUI
import AppKit
import ServiceManagement

// CGEventType 14 = NX_SYSDEFINED (media keys: play/pause, brightness, volume, etc.)
private let kCGEventNXSysDefined: CGEventType = CGEventType(rawValue: 14)!

@main
struct KeyboardCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - State
    private var statusItem: NSStatusItem?
    private var isLocked = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var autoUnlockTimer: Timer?

    // MARK: - Menu items (kept as references for updates)
    private var lockMenuItem: NSMenuItem?
    private var timerSubmenu: NSMenu?
    private var launchAtLoginItem: NSMenuItem?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: "KeyboardCleaner — unlocked"
        )

        buildMenu()
        checkAccessibilityOnLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Always clean up the event tap before quitting
        if isLocked { performUnlock() }
    }

    // MARK: - Accessibility

    private func checkAccessibilityOnLaunch() {
        // Don't prompt on launch — just check silently.
        // If not trusted, the user will be prompted when they first try to lock.
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        )
        if !trusted {
            showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "KeyboardCleaner needs Accessibility access to intercept keyboard events.\n\nOpen System Settings → Privacy & Security → Accessibility and enable KeyboardCleaner."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        // Lock / Unlock
        let lockItem = NSMenuItem(title: "Lock Keyboard", action: #selector(toggleLock), keyEquivalent: "")
        lockItem.target = self
        menu.addItem(lockItem)
        self.lockMenuItem = lockItem

        menu.addItem(.separator())

        // Auto-Unlock Timer submenu
        let timerParent = NSMenuItem(title: "Auto-Unlock Timer", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let timerOptions: [(String, Int)] = [
            ("Off",        0),
            ("1 minute",  60),
            ("3 minutes", 180),
            ("5 minutes", 300),
            ("10 minutes",600),
        ]
        for (title, seconds) in timerOptions {
            let item = NSMenuItem(title: title, action: #selector(selectTimer(_:)), keyEquivalent: "")
            item.target = self
            item.tag = seconds
            item.state = seconds == 0 ? .on : .off   // "Off" is default
            sub.addItem(item)
        }
        timerParent.submenu = sub
        menu.addItem(timerParent)
        self.timerSubmenu = sub

        menu.addItem(.separator())

        // Launch at Login
        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)
        self.launchAtLoginItem = loginItem

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit KeyboardCleaner", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func refreshMenuState() {
        lockMenuItem?.title = isLocked ? "Unlock Keyboard" : "Lock Keyboard"
    }

    // MARK: - Lock / Unlock

    @objc private func toggleLock() {
        isLocked ? performUnlock() : performLock()
        refreshMenuState()
    }

    private func performLock() {
        guard !isLocked else { return }

        // Verify accessibility at the moment of locking
        guard AXIsProcessTrusted() else {
            showAccessibilityAlert()
            return
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)    |
            (1 << CGEventType.keyUp.rawValue)      |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << kCGEventNXSysDefined.rawValue)   // media / special keys

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, _, _ -> Unmanaged<CGEvent>? in
                return nil   // swallow the event
            },
            userInfo: nil
        )

        guard let tap = eventTap else {
            // tapCreate fails when Accessibility is not granted despite AXIsProcessTrusted
            showAccessibilityAlert()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isLocked = true
        statusItem?.button?.image = NSImage(
            systemSymbolName: "lock.fill",
            accessibilityDescription: "KeyboardCleaner — locked"
        )

        playSound(named: "Submarine")
        scheduleAutoUnlockIfNeeded()
    }

    private func performUnlock() {
        guard isLocked else { return }

        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil

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
        statusItem?.button?.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: "KeyboardCleaner — unlocked"
        )

        playSound(named: "Glass")
        resetTimerMenuSelection()
    }

    // MARK: - Auto-Unlock Timer

    @objc private func selectTimer(_ sender: NSMenuItem) {
        // Uncheck all, check selected
        timerSubmenu?.items.forEach { $0.state = .off }
        sender.state = .on

        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil

        let seconds = sender.tag
        guard seconds > 0 else { return }

        // Only schedule if currently locked; otherwise it will be picked up on next lock
        if isLocked {
            autoUnlockTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
                guard let self else { return }
                self.performUnlock()
                self.refreshMenuState()
            }
        }
    }

    private func scheduleAutoUnlockIfNeeded() {
        guard let checkedItem = timerSubmenu?.items.first(where: { $0.state == .on }),
              checkedItem.tag > 0 else { return }

        autoUnlockTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(checkedItem.tag),
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.performUnlock()
            self.refreshMenuState()
        }
    }

    private func resetTimerMenuSelection() {
        timerSubmenu?.items.forEach { $0.state = .off }
        timerSubmenu?.items.first?.state = .on  // "Off"
    }

    // MARK: - Launch at Login

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
            } catch {
                // Silently ignore — user can retry
            }
        }
    }

    // MARK: - Sound

    private func playSound(named name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }

    // MARK: - Quit

    @objc private func quitApp() {
        if isLocked { performUnlock() }
        NSApp.terminate(nil)
    }
}
