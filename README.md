# KeyboardCleaner

A minimal macOS menu bar app that locks keyboard input so you can clean your keys without triggering anything. Trackpad and mouse remain fully functional.

## Features

- One-click keyboard lock from the menu bar
- **Auto-Unlock Timer** — automatically unlock after 1, 3, 5, or 10 minutes
- **Launch at Login** — toggle from the menu, no manual setup
- Blocks all key events system-wide including media keys (volume, brightness, play/pause)
- Distinct sound feedback on lock and unlock
- Guided Accessibility permission setup on first launch
- Tiny footprint — no background services, no Launch Agents

## Install

### Option 1 — Homebrew (recommended)

```bash
brew tap egowic/tap
brew install --cask keyboard-cleaner
```

### Option 2 — curl

```bash
curl -L https://github.com/egowic/KeyboardCleaner/releases/latest/download/KeyboardCleaner.zip \
  -o /tmp/KeyboardCleaner.zip && unzip /tmp/KeyboardCleaner.zip -d /Applications
```

Then launch KeyboardCleaner from `/Applications`.

### "Unverified developer" warning

macOS may block the app on first launch. To open it anyway:

1. In Finder, go to `/Applications`
2. **Right-click** `KeyboardCleaner.app` → **Open**
3. Click **Open** in the dialog

After that, it opens normally without the warning.

### Accessibility Permission

KeyboardCleaner requires **Accessibility** access to intercept keyboard events. On first launch the app will guide you — or go to **System Settings → Privacy & Security → Accessibility** and enable KeyboardCleaner manually.

## Usage

1. Click the keyboard icon in the menu bar
2. Select **Lock Keyboard** — keyboard input is now blocked (icon changes to a lock)
3. Optionally set an **Auto-Unlock Timer** from the submenu
4. Clean your keys
5. Select **Unlock Keyboard** (or use the trackpad to click the menu bar icon)

## Uninstall

```bash
# Homebrew
brew uninstall --cask keyboard-cleaner

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
