import SwiftUI
import AppKit

@main
struct KeyboardCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var isLocked = false
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard Cleaner")
        }

        setupMenu()
    }

    func setupMenu() {
        let menu = NSMenu()

        let lockItem = NSMenuItem(title: "Lock", action: #selector(toggleLock), keyEquivalent: "")
        lockItem.target = self
        menu.addItem(lockItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func updateMenu() {
        if let menu = statusItem?.menu, let lockItem = menu.items.first {
            lockItem.title = isLocked ? "Unlock" : "Lock"
        }
    }

    @objc func toggleLock() {
        isLocked ? unlock() : lock()
        updateMenu()
    }

    @objc func quitApp() {
        if isLocked { unlock() }
        NSApp.terminate(nil)
    }

    func lock() {
        guard !isLocked else { return }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << 14)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, _, _ -> Unmanaged<CGEvent>? in
                return nil
            },
            userInfo: nil
        )

        guard let tap = eventTap else {
            let alert = NSAlert()
            alert.messageText = "Accessibility permission required"
            alert.informativeText = "System Settings → Privacy & Security → Accessibility → Enable KeyboardCleaner."
            alert.runModal()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isLocked = true
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Locked")
        }
    }

    func unlock() {
        guard isLocked else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        isLocked = false
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard Cleaner")
        }
    }
}
