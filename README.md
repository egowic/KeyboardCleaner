# KeyboardCleaner

A minimal macOS menu bar app that locks keyboard input so you can clean your keys without triggering anything. Trackpad and mouse remain fully functional.

## Features

- One-click keyboard lock from the menu bar
- **Lock overlay** — floating panel stays on screen while locked, with an Unlock button
- **Composite menu bar icon** — keyboard + open lock when unlocked, keyboard + closed lock when locked
- Blocks all key events system-wide including media keys (volume, brightness, play/pause)
- Distinct sound feedback on lock and unlock
- **Launch at Login** — toggle from the menu, no manual setup
- Guided Accessibility permission setup on first launch

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

## Usage

1. Click the menu bar icon (keyboard + open lock)
2. Select **Lock Keyboard** — a floating panel appears, keyboard input is blocked
3. Clean your keys
4. Click **Unlock** on the panel (or use the menu bar icon → **Unlock Keyboard**)

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
