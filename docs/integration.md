# Bento integration guide

Bento is built to be glued into the rest of your macOS automation stack. This document covers the contracts integrators (Hammerspoon, Karabiner, Shortcuts, Stream Deck Mobile, custom shell wrappers) can rely on.

## Trigger surfaces

| Surface | Example |
|---|---|
| Global hotkey | `⌃⌘B` toggles the panel |
| CLI | `bento press <id-or-label>` |
| URL scheme | `open 'bento://press/<id-or-label>'` |
| Distributed Notifications | post `bento.pressTile` with `userInfo: {"needle": "<id>"}` |

All four trigger the same code path: `BentoURLHandler.press(needle:)`.

## CLI exit codes

`bento press` exits with one of:

- `0` — Bento.app received the request and acknowledged within 2 s
- `1` — App did not acknowledge within 2 s × 2 attempts (with auto-launch retry between). Tile may not exist, app may be mid-update, or app may have crashed. Stderr contains the helpful error.
- `2` — Usage error (missing argument, unknown subcommand)

`bento list` exits `1` if the deck is missing, `0` otherwise.

`bento doctor` exits `1` if any check fails, `0` otherwise. Use `bento doctor --json` for machine-readable output and `jq` to gate other workflows.

## CLI ↔ App ack round-trip

The CLI generates a UUID per `press` request and posts `bento.pressTile` with `replyTo: <uuid>` in `userInfo`. The app posts `bento.pressTile.ack.<uuid>` back as soon as it receives the request (before executing the press). The CLI waits up to 2 seconds for the ack.

This means: if `bento press` returns 0, the app received your request. It does NOT mean the press has finished executing — long-running tile actions (e.g. shell commands that take seconds) still run async after the ack.

## Sparkle update window — what happens to in-flight presses

When the user clicks "Check for Updates…" in the App menu and Sparkle decides to install an update, it relaunches Bento.app. Between the moment the old process quits and the moment the new process installs its `DistributedNotificationCenter` observer, **no observer is listening for `bento.pressTile`**.

If a Hammerspoon binding fires `bento press dark` during that window:

1. First attempt: 2 s timeout (no observer to ack).
2. CLI calls `open -g -a Bento.app`. macOS launches the new Bento.app (post-update version).
3. CLI sleeps 0.5 s, then retries.
4. Second attempt: succeeds (new process has installed the observer).
5. Total worst-case latency: ~3 s. This only happens during the update window, which is at most a few seconds per release.

If you have stricter latency requirements (e.g., you don't want a 3 s stall during media-control bindings), wrap the CLI in your own retry loop with a shorter timeout and a graceful fallback.

## Authentication

`DistributedNotificationCenter` is **unauthenticated**: any process running as the same user can post `bento.pressTile` and trigger any tile, including shell-action tiles. This is by design for ergonomics (Hammerspoon, Karabiner, custom scripts all "just work"), but it means malicious local code can press your tiles.

Mitigations available today:
- Don't put destructive shell commands in tiles (`rm -rf`, `sudo`, etc.) without confirming you trust every other process running as your user.
- Audit your `deck.json` periodically.

A future version (v0.3+) is planned to switch the IPC layer to `NSXPCConnection` with audit-token validation — see `TODOS.md` for the tracking note.

## URL scheme contract

`bento://press/<needle>` — the `<needle>` is URL-encoded and passed to `BentoURLHandler.press(needle:)` exactly as the CLI's `bento press` does. Useful from Stream Deck Mobile, Karabiner, or any URL-handling automation.

```bash
open 'bento://press/dark'                 # by label or id (kebab-case-aware)
open 'bento://press/Toggle%20DND'         # URL-encoded label
```

## Listing tiles for downstream tools

- `bento list` — human readable
- `bento list --ids` — one UUID per line. Pipe to `fzf` for a picker:
  ```bash
  bento press "$(bento list --ids | fzf)"
  ```
- `bento list --json` — full deck JSON. Pipe to `jq` for filtering:
  ```bash
  bento list --json | jq -r '.[] | select(.label == "Coffee") | .id'
  ```

## Hammerspoon recipes

```lua
-- Fire a tile from a Hammerspoon hotkey, with graceful fallback if Bento is not running
local function pressTile(needle)
    local ok = hs.execute("/usr/local/bin/bento press " .. needle)
    if not ok then
        hs.alert.show("Bento not running")
    end
end

hs.hotkey.bind({"ctrl", "alt"}, "D", function() pressTile("dark") end)
hs.hotkey.bind({"ctrl", "alt"}, "C", function() pressTile("coffee") end)
```

## Karabiner-Elements recipes

In `~/.config/karabiner/karabiner.json` (or via Karabiner's GUI):

```json
{
  "type": "basic",
  "from": { "key_code": "f13" },
  "to": [
    { "shell_command": "/usr/local/bin/bento press dark" }
  ]
}
```

## Shortcuts.app recipes

Add a "Run Shell Script" action with `/usr/local/bin/bento press dark`. Shortcuts on macOS 14+ supports shell actions inside Quick Actions, Menu Bar, and the Shortcuts app itself.

## Stream Deck Mobile

Use the "Open URL" action with `bento://press/dark`. The app opens the URL via the system URL handler and Bento.app picks it up.

## Skipping postinstall in CI / Docker / restricted networks

```bash
BENTO_SKIP_POSTINSTALL=1 npm install -g bento-deck
```

This skips the Bento.app download. The shim still installs at `/usr/local/lib/node_modules/bento-deck/bin/bento.js` but exits with a useful error when invoked because no Bento.app is found. You can install Bento.app separately (DMG, build from source) and the shim will pick it up.

## Custom CLI symlink path

```bash
BENTO_CLI_DIR=$HOME/bin npm install -g bento-deck
```

Postinstall will symlink `bento` into `$BENTO_CLI_DIR` instead of `/usr/local/bin` or `~/.local/bin`. Useful for Nix, asdf, or any setup with non-standard `bin` directories.

## Suppressing the version-drift warning

```bash
BENTO_SUPPRESS_VERSION_CHECK=1
```

Set this if you intentionally pin different bento-deck and Bento.app versions (e.g. testing).
