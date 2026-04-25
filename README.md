# KeyboardCleaner

A minimal macOS menu bar app that locks keyboard input so you can clean your keys without triggering anything. Trackpad and mouse remain fully functional.

Shutting down to clean your keyboard? A single keypress will power your Mac right back on. KeyboardCleaner blocks all keyboard input without shutting down — trackpad and mouse stay fully functional.

## Features

- One-click keyboard lock from the menu bar
- **Lock overlay** — floating panel centered on screen while locked, with an Unlock button
- **Click blocker** — while locked, only the menu bar remains interactive (Dock and desktop are blocked)
- **Composite menu bar icon** — keyboard + open lock when unlocked, keyboard + closed lock when locked
- Blocks all key events system-wide including media keys (volume, brightness, play/pause)
- **Auto-update** — automatically downloads and installs new versions in the background
- **Launch at Login** — toggle from the menu, no manual setup
- Guided Accessibility permission setup on first launch
- Distinct sound feedback on lock and unlock

## Install

### Option 1 — Homebrew (recommended)

If you don't have Homebrew installed, get it first from [brew.sh](https://brew.sh):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install KeyboardCleaner:

```bash
brew tap egowic/tap
brew install --cask keycleaner
```

### Option 2 — Direct download

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

KeyboardCleaner checks for updates automatically on each launch. When a new version is available, it will download and install it for you — just click **Relaunch Now** when prompted.

You can also check manually via the menu bar icon → **Check for Updates…**

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

# Direct download
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
