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

    // Overlay: floating panel + full-screen click blocker
    private var overlayPanel: NSPanel?
    private var clickBlockerWindow: NSWindow?

    // Menu item references
    private var lockMenuItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = menuBarImage(locked: false)

        buildMenu()
        checkAccessibilityOnLaunch()
        checkForUpdatesInBackground()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isLocked { performUnlock() }
    }

    // MARK: - Menu Bar Icon

    private func menuBarImage(locked: Bool) -> NSImage {
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

    // MARK: - Accessibility

    private func checkAccessibilityOnLaunch() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        NSLog("KeyboardCleaner: launch trusted=\(trusted)")
    }

    private func showRestartAlert() {
        let alert = NSAlert()
        alert.messageText = "Almost there — please restart KeyboardCleaner"
        alert.informativeText = "You've granted Accessibility access, but KeyboardCleaner needs to be relaunched for the permission to take effect."
        alert.addButton(withTitle: "Quit & Relaunch")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational
        if alert.runModal() == .alertFirstButtonReturn { relaunchApp() }
    }

    private func showAccessibilityNeededAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "KeyboardCleaner needs Accessibility access to lock keyboard input.\n\nOpen System Settings → Privacy & Security → Accessibility and enable KeyboardCleaner, then relaunch the app."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }

    private func relaunchApp() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", Bundle.main.bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        let lockItem = NSMenuItem(title: "Lock Keyboard", action: #selector(toggleLock), keyEquivalent: "")
        lockItem.target = self
        menu.addItem(lockItem)
        self.lockMenuItem = lockItem

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesManually), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

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

    // MARK: - Lock / Unlock

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

    // MARK: - Overlay + Click Blocker

    private func showOverlay() {
        showClickBlocker()

        let size = NSSize(width: 320, height: 260)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
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

        // Center within the visible frame (excludes menu bar + Dock)
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let x = vf.midX - size.width / 2
            let y = vf.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        panel.orderFrontRegardless()
        self.overlayPanel = panel
    }

    private func hideOverlay() {
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
        hideClickBlocker()
    }

    /// Full-screen transparent window that swallows all mouse clicks
    /// except the menu bar (which sits at a higher window level).
    private func showClickBlocker() {
        guard let screen = NSScreen.main else { return }

        let blocker = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        blocker.isMovable = false
        // Level 23: above Dock (~20), below menu bar (24) and our overlay panel (25)
        blocker.level = NSWindow.Level(rawValue: 23)
        blocker.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        blocker.backgroundColor = NSColor.clear
        blocker.isOpaque = false
        blocker.ignoresMouseEvents = false
        blocker.hidesOnDeactivate = false

        // Transparent NSView that eats all clicks silently
        let eater = ClickEaterView(frame: screen.frame)
        blocker.contentView = eater
        blocker.orderFrontRegardless()
        self.clickBlockerWindow = blocker
    }

    private func hideClickBlocker() {
        clickBlockerWindow?.orderOut(nil)
        clickBlockerWindow = nil
    }

    // MARK: - Update Checker

    private let githubRepo = "egowic/KeyboardCleaner"
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private func checkForUpdatesInBackground() {
        Task.detached(priority: .background) { [weak self] in
            await self?.fetchLatestRelease(silent: true)
        }
    }

    @objc private func checkForUpdatesManually() {
        Task.detached { [weak self] in
            await self?.fetchLatestRelease(silent: false)
        }
    }

    private func fetchLatestRelease(silent: Bool) async {
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }

            // Strip leading "v" if present
            let latest = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let htmlURL = json["html_url"] as? String ?? "https://github.com/\(githubRepo)/releases/latest"

            NSLog("KeyboardCleaner: current=\(currentVersion) latest=\(latest)")

            guard isNewerVersion(latest, than: currentVersion) else {
                if !silent {
                    await showUpToDateAlert()
                }
                return
            }

            await showUpdateAvailableAlert(version: latest, url: htmlURL)

        } catch {
            NSLog("KeyboardCleaner: update check failed: \(error)")
            if !silent {
                await showUpdateCheckFailedAlert()
            }
        }
    }

    /// Returns true if `a` is a newer semantic version than `b`
    private func isNewerVersion(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }

    @MainActor
    private func showUpdateAvailableAlert(version: String, url: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available — v\(version)"
        alert.informativeText = "You're running v\(currentVersion). Version \(version) is available on GitHub."
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational
        if alert.runModal() == .alertFirstButtonReturn,
           let releaseURL = URL(string: url) {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    @MainActor
    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "KeyboardCleaner v\(currentVersion) is the latest version."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    @MainActor
    private func showUpdateCheckFailedAlert() {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Could not reach GitHub. Check your internet connection and try again."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
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
            } catch { }
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

// MARK: - Click Eater View

/// Transparent NSView that consumes all mouse events, blocking
/// interaction with windows behind the lock overlay.
final class ClickEaterView: NSView {
    override func mouseDown(with event: NSEvent) { /* swallow */ }
    override func mouseUp(with event: NSEvent) { /* swallow */ }
    override func rightMouseDown(with event: NSEvent) { /* swallow */ }
    override func rightMouseUp(with event: NSEvent) { /* swallow */ }
    override func otherMouseDown(with event: NSEvent) { /* swallow */ }
    override func otherMouseUp(with event: NSEvent) { /* swallow */ }
    override func mouseDragged(with event: NSEvent) { /* swallow */ }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
