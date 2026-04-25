# KeyboardCleaner

A minimal macOS menu bar app that locks keyboard input so you can clean your keys without triggering anything. Trackpad and mouse remain fully functional.

## Features

- One-click keyboard lock from the menu bar
- **Lock overlay** — floating panel centered on screen while locked, with an Unlock button
- **Click blocker** — while locked, only the menu bar remains interactive (Dock and desktop are blocked)
- **Composite menu bar icon** — keyboard + open lock when unlocked, keyboard + closed lock when locked
- Blocks all key events system-wide including media keys (volume, brightness, play/pause)
- **Built-in update checker** — notifies you when a new version is available
- **Launch at Login** — toggle from the menu, no manual setup
- Guided Accessibility permission setup on first launch
- Distinct sound feedback on lock and unlock

## Install

### Option 1 — Homebrew (recommended)

```bash
brew tap egowic/tap
brew install --cask keycleaner
```

### Option 2 — curl

```bash
curl -L https://github.com/egowic/KeyboardCleaner/releases/latest/download/KeyboardCleaner.zip \
  -o /tmp/KeyboardCleaner.zip && unzip /tmp/KeyboardCleaner.zip -d /Applications
```

### "Unverified developer" warning

macOS may block the app on first launch. To open it anyway:

1. In Finder, go to `/Applications`
2. **Right-click** `KeyboardCleaner.app` → **Open**
3. Click **Open** in the dialog

### Accessibility Permission

KeyboardCleaner requires **Accessibility** access to intercept keyboard events. On first launch macOS will show a system dialog — click **Open System Settings**, then enable KeyboardCleaner in the list.

> If the app needs to restart after granting permission, it will prompt you automatically.

## Update

### Homebrew

```bash
brew update && brew upgrade --cask keycleaner
```

### Manual / curl

The app checks for updates automatically on each launch and notifies you when a new version is available. You can also check manually via the menu bar icon → **Check for Updates…**

To update manually:

```bash
curl -L https://github.com/egowic/KeyboardCleaner/releases/latest/download/KeyboardCleaner.zip \
  -o /tmp/KeyboardCleaner.zip && unzip -o /tmp/KeyboardCleaner.zip -d /Applications
```

## Usage

1. Click the menu bar icon (keyboard + open lock)
2. Select **Lock Keyboard** — a floating panel appears, keyboard input is blocked
3. While locked:
   - The overlay panel stays centered on screen
   - Desktop and Dock clicks are blocked
   - The menu bar remains accessible
4. Click **Unlock** on the panel (or menu bar icon → **Unlock Keyboard**)

## Uninstall

```bash
# Homebrew
brew uninstall --cask keycleaner

# Manual
rm -rf /Applications/KeyboardCleaner.app
```

## Build from source

Requires Xcode 15+, macOS 13+.

```bash
git clone https://github.com/egowic/KeyboardCleaner.git
cd KeyboardCleaner
open KeyboardCleaner.xcodeproj
```

Build and run with `⌘R`.
