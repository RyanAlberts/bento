# `bento` CLI

After `npm install -g bento` or `./scripts/install-cli.sh`, you have a `bento` command on your PATH. It talks to the running app via Distributed Notifications, so the app must be running for `press` and `toggle` to do anything.

## Subcommands

```
bento press <id-or-label>   Fire a tile
bento toggle                Show or hide the panel
bento list                  Print every tile (label, symbol, ID)
bento doctor                Print config path + status diagnostics
bento export                Dump deck.json to stdout
bento import                Replace deck.json with stdin
bento --version             Print the version
```

## Examples

```bash
# Fire a tile
bento press dark

# Pipe a recipe in
cat recipes/obs-scene-switcher.json | bento import

# Cross-machine dotfile sync
bento export > ~/dotfiles/bento-deck.json
bento import < ~/dotfiles/bento-deck.json

# Self-diagnosis
bento doctor
```

## Hammerspoon binding

```lua
hs.hotkey.bind({"alt"}, "1", function()
  hs.execute("/usr/local/bin/bento press dark")
end)
```

## Karabiner binding

In `~/.config/karabiner/karabiner.json`, map a key to:

```json
{
  "type": "shell_command",
  "shell_command": "/usr/local/bin/bento press dark"
}
```
