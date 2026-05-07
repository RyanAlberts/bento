# bento

A minimal, fun, open-source soft Stream Deck for macOS.

```
npm install -g bento-deck
```

That installs `Bento.app` to `/Applications` and a `bento` command on your PATH. No Gatekeeper dialog, no hardware, no subscription, no telemetry.

Launch the app, press `⌃⌘B` from anywhere, and you'll see a floating grid of 8 tiles you can press to:

- Toggle dark mode
- Caffeinate for an hour (with a live progress ring)
- Mute the mic (turns red when muted)
- Snap a screenshot
- Eject all disks
- Sleep displays
- Play / pause media
- Run a 25-minute focus timer

`⌘-click` any tile to edit it. Click the `+` to add your own — launch any app, open any URL, or run any shell command. The shell action is the universal escape hatch: AppleScript, Shortcuts, Hammerspoon, HomeKit — anything you can write in zsh.

```bash
bento --help            # show subcommands
bento press dark        # fire a tile from the terminal
bento export > deck.json   # dotfile-friendly round-trip
bento doctor            # self-diagnosis
```

## Full docs and source

[github.com/RyanAlberts/bento](https://github.com/RyanAlberts/bento)

## A star helps a lot

If you build something useful with this, dropping a ⭐ on the repo is what keeps indie projects discoverable.
