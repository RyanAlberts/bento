import Foundation

enum DefaultDeck {
    /// Default tile order, optimized for keyboard arrow navigation starting top-left.
    /// Row 1: AI · Snap · Coffee · Focus  — productivity / capture / time-bound modes
    /// Row 2: Notes · Mic · Dark · Sleep   — content / state / system controls
    /// Plus tile: Row 3, slot 1 — the entry point for adding your own.
    static var tiles: [Tile] {
        [
            Tile(
                label: "AI",
                symbol: "sparkles",
                tint: .accent,
                // Google AI Mode (udm=50) — opens straight into the AI answer pane,
                // no permissions needed since it's just a URL open.
                action: .shell("open 'https://www.google.com/?udm=50'"),
                info: "Open a fresh Google AI Mode tab in your default browser. Type your question; AI answers inline."
            ),
            Tile(
                label: "Snap",
                symbol: "camera.viewfinder",
                tint: .neutral,
                // We hand off to macOS Screenshot.app instead of `screencapture -ic`.
                // `screencapture` itself requires Screen Recording permission, and on
                // every Bento rebuild the binary signature changes so TCC re-prompts
                // even when the user has already toggled the setting on. Screenshot.app
                // has its own permanent Screen Recording grant on most Macs (granted
                // the first time the user ever pressed ⌘⇧5), so opening it is the
                // permission-free path. Slight launch lag (~200ms first time) is the
                // cost of zero re-prompts.
                action: .shell("open -a Screenshot"),
                info: "Open macOS Screenshot — pick region, window, or full screen. Press Esc to dismiss."
            ),
            Tile(
                label: "Coffee",
                symbol: "cup.and.saucer.fill",
                tint: .neutral,
                action: .shell("caffeinate -d -t 3600 &"),
                liveKind: .caffeinate,
                info: "Stop your Mac from sleeping for 60 minutes. Live ring traces the countdown. For long meetings, downloads, or presentations."
            ),
            Tile(
                label: "Focus",
                symbol: "target",
                tint: .neutral,
                // 25-min stay-awake, then a Glass chime via afplay. We deliberately
                // skip `display notification` because it triggers the UserNotifications
                // permission prompt — sound stays quiet on the permission front.
                action: .shell("caffeinate -d -i -t 1500 ; afplay /System/Library/Sounds/Glass.aiff &"),
                liveKind: .focus,
                info: "Start a 25-minute focus session. Mac stays awake, you hear a chime when it ends. Pomodoro-style."
            ),
            Tile(
                label: "Notes",
                symbol: "note.text",
                tint: .neutral,
                action: .shell("open -a Notes"),
                info: "Open the macOS Notes app. (⌘-click the tile to point it at your favorite note app instead.)"
            ),
            Tile(
                label: "Mic",
                symbol: "mic.slash.fill",
                tint: .neutral,
                action: .shell(#"osascript -e 'set v to input volume of (get volume settings)' -e 'if v > 0 then' -e 'set volume input volume 0' -e 'else' -e 'set volume input volume 75' -e 'end if'"#),
                liveKind: .mic,
                info: "Toggle the system microphone mute. Tile glows red when muted. Lives in any app — Zoom, Meet, FaceTime."
            ),
            Tile(
                label: "Dark",
                symbol: "moon.fill",
                tint: .neutral,
                action: .shell(#"osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'"#),
                info: "Toggle macOS Dark Mode on/off. First click asks once for permission to talk to System Events."
            ),
            Tile(
                label: "Sleep",
                symbol: "moon.zzz.fill",
                tint: .neutral,
                action: .shell("pmset displaysleepnow"),
                info: "Put your displays to sleep right now. Doesn't sleep the whole Mac — just turns the screen off."
            ),
        ]
    }
}
