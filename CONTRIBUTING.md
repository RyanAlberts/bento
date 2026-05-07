# Contributing to Bento

Thanks for considering it. Bento is a deliberately small app — that's the whole point — so PRs that add features get a careful review, and PRs that add tile recipes get fast-merged.

## Three places worth knowing

- `Sources/Bento/Defaults/DefaultDeck.swift` — the 8 default tiles. Edit a label, swap an SF Symbol, change an action.
- `recipes/` — community tile fragments. Drop in a JSON file and submit a PR. No code review required as long as the JSON parses.
- `Sources/Bento/Models/` — the `Tile` model, the `Action` protocol, and the three concrete actions. Add a new action type by conforming to `Action` and registering in `AnyAction.execute()`.

## Build + run

```bash
git clone https://github.com/RyanAlberts/bento.git
cd bento
./scripts/build-app.sh debug
open build/Bento.app
```

That's it. If you have full Xcode installed, `open Package.swift` for previews and breakpoints.

## Recipe PRs (fast-merge)

A recipe is a single JSON file in `recipes/` describing one tile or a small set of tiles. Format:

```json
{
  "name": "OBS scene switcher",
  "description": "One tile per OBS scene. Press to switch.",
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

Drop it in `recipes/`, submit a PR. We'll merge as long as:
1. The JSON parses
2. The shell command isn't destructive without a clear warning
3. Any external dependency (e.g., `obs-cli`) is named in the description

## Code PRs

For changes to the app code:
1. Open an issue first if it's bigger than ~50 lines — saves both of us time
2. Keep PRs focused. One change per PR
3. The diff should be `<300` lines for a fast review
4. Run the app locally before submitting; describe what you tested

## Style

- Swift API Design Guidelines
- One-line docstrings only when the *why* is non-obvious; the *what* should be clear from the names
- No emoji in code or comments unless they're part of an SF Symbol identifier

## Code of conduct

Be kind. The bar is "would you say this to a colleague at a coffee shop." If the answer is no, edit before sending.
