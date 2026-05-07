import Foundation

enum DefaultDeck {
    static var tiles: [Tile] {
        [
            Tile(
                label: "Dark",
                symbol: "moon.fill",
                tint: .neutral,
                action: .shell(#"osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'"#),
                info: "Toggle macOS Dark Mode on/off. First click asks once for permission to talk to System Events."
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
                label: "Coffee",
                symbol: "cup.and.saucer.fill",
                tint: .accent,
                action: .shell("caffeinate -d -t 3600 &"),
                liveKind: .caffeinate,
                info: "Stop your Mac from sleeping for 60 minutes. Live ring traces the countdown. For long meetings, downloads, or presentations."
            ),
            Tile(
                label: "Snap",
                symbol: "camera.viewfinder",
                tint: .neutral,
                // Using macOS's Screenshot.app instead of `screencapture -i` shell-invoke — the
                // shell path has flaky Screen Recording TCC behavior when spawned from a regular
                // app on Tahoe. Screenshot.app gives users the same crosshair UI + the region /
                // window / full-screen toggle, all without TCC tangles.
                action: .shell("open -a Screenshot"),
                info: "Open macOS Screenshot — pick region, window, or full screen. Press Esc to dismiss without capturing."
            ),
            Tile(
                label: "Notes",
                symbol: "note.text",
                tint: .neutral,
                action: .shell("open -a Notes"),
                info: "Open the macOS Notes app. (Replace with your favorite note app — see the README for how to customize.)"
            ),
            Tile(
                label: "Sleep",
                symbol: "moon.zzz.fill",
                tint: .neutral,
                action: .shell("pmset displaysleepnow"),
                info: "Put your displays to sleep right now. Doesn't sleep the whole Mac — just turns the screen off."
            ),
            Tile(
                label: "Focus",
                symbol: "target",
                tint: .accent,
                action: .shell(#"caffeinate -d -i -t 1500 ; osascript -e 'display notification "Focus session complete" with title "Bento" sound name "Glass"' &"#),
                liveKind: .focus,
                info: "Start a 25-minute focus session. Mac stays awake, you get a sound + notification when it ends. Pomodoro-style."
            ),
            Tile(
                label: "AI",
                symbol: "sparkles",
                tint: .accent,
                // Google AI Mode (udm=50) — opens straight into the AI answer pane,
                // no permissions needed since it's just a URL open.
                action: .shell("open 'https://www.google.com/?udm=50'"),
                info: "Open a fresh Google AI Mode tab in your default browser. Type your question; AI answers inline."
            ),
        ]
    }
}
