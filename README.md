# KeyboardCleaner

A minimal macOS menu bar app that locks keyboard input so you can clean your keys without triggering anything. Trackpad and mouse remain fully functional.

## Features

- One-click keyboard lock from the menu bar
- Uses CGEventTap to intercept all key events system-wide
- Mouse and trackpad stay active while keyboard is locked
- Tiny footprint — no background services, no Launch Agents

## Install

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

### Permissions

KeyboardCleaner requires **Accessibility** access to intercept keyboard events. On first launch, macOS will prompt you — grant access in **System Settings → Privacy & Security → Accessibility**.

## Usage

1. Click the keyboard icon in the menu bar
2. Select **Lock** — keyboard input is now blocked
3. Clean your keys
4. Select **Unlock** (or use the trackpad to click the menu bar icon → **Unlock**)

## Uninstall

```bash
rm -rf /Applications/KeyboardCleaner.app
```

## Build from source

Requires Xcode 15+.

```bash
git clone https://github.com/egowic/KeyboardCleaner.git
open KeyboardCleaner/KeyboardCleaner.xcodeproj
```

Build and run with ⌘R.
