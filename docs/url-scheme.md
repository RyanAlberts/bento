# `bento://` URL scheme

Bento registers `bento://` as a system URL scheme. Any process that can `open` a URL can fire a tile.

## Forms

```
bento://press/<id-or-slug>
bento://confetti
```

### `press`
Looks up a tile by either its UUID or its slugified label and runs its action.

```bash
open 'bento://press/dark'                                   # by label
open 'bento://press/5C2C2A50-8B5F-4E89-9D62-7B3F3A2B1B3F'   # by ID
```

### `confetti`
Fires the confetti overlay across the panel. (Same as shift-clicking the menu bar icon.)

## Use cases

- Apple Shortcuts → "Open URLs" action with `bento://press/dark`
- Raycast script-command → `open bento://press/coffee`
- Browser bookmark → bookmark `bento://press/focus` and click it from any web page
- Stream Deck Mobile → "Open URL" action

## Caveats

The first time something *other than Bento* opens a `bento://` URL, macOS may prompt to choose Bento as the handler. Click "Always Allow" to make it stick.
