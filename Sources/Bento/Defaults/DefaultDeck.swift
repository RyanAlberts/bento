import Foundation

enum DefaultDeck {
    static var tiles: [Tile] {
        [
            Tile(
                label: "Dark",
                symbol: "moon.fill",
                tint: .neutral,
                action: .shell(#"osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'"#)
            ),
            Tile(
                label: "Eject",
                symbol: "eject.fill",
                tint: .neutral,
                action: .shell(#"osascript -e 'tell application "Finder" to eject (every disk whose ejectable is true)'"#)
            ),
            Tile(
                label: "Mic",
                symbol: "mic.slash.fill",
                tint: .neutral,
                action: .shell(#"osascript -e 'set v to input volume of (get volume settings)' -e 'if v > 0 then' -e 'set volume input volume 0' -e 'else' -e 'set volume input volume 75' -e 'end if'"#),
                liveKind: .mic
            ),
            Tile(
                label: "Coffee",
                symbol: "cup.and.saucer.fill",
                tint: .accent,
                action: .shell("caffeinate -d -t 3600 &"),
                liveKind: .caffeinate
            ),
            Tile(
                label: "Snap",
                symbol: "camera.viewfinder",
                tint: .neutral,
                action: .shell(#"screencapture -i "$HOME/Desktop/shot-$(date +%s).png""#)
            ),
            Tile(
                label: "Play",
                symbol: "play.fill",
                tint: .neutral,
                // v1 fallback: use AppleScript media-key cheat through Music.app.
                // The proper HIDPostAuxKey path requires a tiny C bridge; deferred to v0.2.
                action: .shell(#"osascript -e 'tell application "System Events" to key code 100'"#)
            ),
            Tile(
                label: "Sleep",
                symbol: "moon.zzz.fill",
                tint: .neutral,
                action: .shell("pmset displaysleepnow")
            ),
            Tile(
                label: "Focus",
                symbol: "target",
                tint: .accent,
                action: .shell("caffeinate -d -i -t 1500 &"),
                liveKind: .focus
            ),
        ]
    }
}
