# Hammerspoon × Bento recipes

Bento and [Hammerspoon](https://www.hammerspoon.org/) are made for each other: Hammerspoon owns the keyboard and the system, Bento owns the always-visible buttons. Glue them together.

## Bind extra hotkeys to tiles

```lua
hs.hotkey.bind({"alt"}, "d", function() hs.execute("/usr/local/bin/bento press dark") end)
hs.hotkey.bind({"alt"}, "c", function() hs.execute("/usr/local/bin/bento press coffee") end)
hs.hotkey.bind({"alt"}, "f", function() hs.execute("/usr/local/bin/bento press focus") end)
```

## Auto-toggle the panel based on the active app

Hide the panel when you're in a fullscreen meeting, show it on the desktop:

```lua
hs.application.watcher.new(function(name, evtType, app)
  if evtType == hs.application.watcher.activated then
    if name == "zoom.us" or name == "Microsoft Teams" then
      hs.execute("/usr/local/bin/bento toggle")
    end
  end
end):start()
```

## Map a button on a Stream Deck Mobile, MIDI controller, or wired keyboard

The pattern is always the same: trigger calls

```bash
/usr/local/bin/bento press <label-or-id>
```

Bento doesn't care what's on the other end of that pipe.

## Pipe Bento's output

Bento's `bento doctor` prints config + state in plain text. You can pipe it into your existing menu bar status display:

```lua
local out, ok = hs.execute("/usr/local/bin/bento doctor")
hs.alert.show(out, 4)
```
