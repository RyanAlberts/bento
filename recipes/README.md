# recipes/

Community-contributed tile fragments. Drop a JSON file here, submit a PR — fast-merge as long as the JSON parses and the description names any external dependencies.

## Format

```json
{
  "name": "Short title — what these tiles are for",
  "description": "One-paragraph explanation. Name any required tools (obs-cli, jq, etc.).",
  "tiles": [
    {
      "label": "Game",
      "symbol": "gamecontroller.fill",
      "tint": "neutral",
      "action": { "kind": "shell", "payload": "obs-cli scene Game" }
    }
  ]
}
```

Valid `tint` values: `neutral`, `accent`, `red`.
Valid `action.kind` values: `shell`, `app`, `url`.

## Importing a recipe

```bash
bento export > my-deck-backup.json   # back up your current deck first
jq '{schemaVersion: 1, tiles: ((.tiles // []) + (input | .tiles))}' my-deck-backup.json recipes/obs-scene-switcher.json | bento import
```

(A friendlier `bento recipe add <name>` command is queued for v0.2.)

## Browse

- [obs-scene-switcher.json](obs-scene-switcher.json) — tiles for switching OBS scenes
- [git-status-checker.json](git-status-checker.json) — tile that opens GitHub status
- [zoom-mute.json](zoom-mute.json) — tile that toggles Zoom's mic via shortcut
