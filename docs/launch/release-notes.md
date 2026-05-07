# Bento v0.1.0 — release notes

> Use this as the body of `gh release create v0.1.0` once you publish to GitHub.

## What's in the box

- 8 default tiles: **Dark · Eject · Mic · Coffee · Snap · Play · Sleep · Focus**
- 3 of those are **live**:
  - **Coffee** + **Focus** show progress rings while their `caffeinate` assertion is active
  - **Mic** glows red while system input is muted
- Floating panel — frameless, glass-material (`NSVisualEffectView` `.popover`), draggable, click-without-stealing-focus from the foreground app (`.nonactivatingPanel`)
- Global hotkey **`⌃⌘B`** to toggle the panel, registered via Carbon `RegisterEventHotKey` (no Accessibility permission required)
- **Confetti easter egg** in the menu bar item dropdown
- Three action types you can build custom tiles around: launch app, open URL, run shell command
- Tile editor sheet (click the `+` tile) and right-click context menu (Edit / Delete)
- Hot-reload — edit `~/Library/Application Support/Bento/deck.json` in your editor and the panel updates within ~1 second via FSEvents
- `bento://press/<id-or-slug>` URL scheme for Hammerspoon / Shortcuts integration
- `bento` CLI binary: `press`, `list`, `doctor`, `export`, `import`
- Zero telemetry, zero analytics, zero accounts, zero network calls (other than the npm postinstall download from this GitHub release)
- macOS 14 (Sonoma) or later, arm64 + x86_64 universal not yet (v0.1 is arm64-only — Universal binary is queued for v0.2)

## Install

**Recommended (one line, no Gatekeeper dance):**

```
npm install -g bento
```

That installs `Bento.app` to `/Applications` and a `bento` command on your PATH. The postinstall strips the quarantine flag so the ad-hoc-signed binary launches without the "from an unidentified developer" prompt.

**Or download the DMG below:**

1. Download `Bento-v0.1.0.dmg`
2. Drag to Applications
3. Right-click `Bento.app` → Open the first time (the .app is ad-hoc-signed, not Apple-notarized — Gatekeeper shows the standard "from an unidentified developer" prompt the first time, click Open)
4. Grant the one-time Automation permission when macOS asks (we pre-warn before the panel appears)

**Or build from source:**

```
git clone https://github.com/ryan-alberts/bento.git
cd bento
./scripts/build-app.sh release
open build/Bento.app
```

## Known gaps in v0.1

- **No auto-update.** Sparkle ships in v0.2. For now, `npm update -g bento` brings the latest.
- **Configurable hotkey** ships in v0.2. v0.1 hardcodes `⌃⌘B`.
- **The Play tile** uses an `osascript` media-key cheat through the active media app; a proper `IOHIDPostEvent`-based bridge is queued for v0.2.
- **No XCTest target** — Command Line Tools doesn't ship XCTest. The library refactor + tests come back in v0.2.
- **Homebrew tap** is a stretch goal post-v0.1.

## A star ⭐ helps a lot

If you find this useful, dropping a star on the repo is what keeps indie projects discoverable. Thanks for taking it for a spin.
