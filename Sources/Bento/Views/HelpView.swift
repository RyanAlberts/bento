import SwiftUI

struct HelpView: View {
    @StateObject private var store = DeckStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section("Privacy") {
                    bullet("Zero telemetry, zero analytics, zero accounts.")
                    bullet("No network calls (other than the npm postinstall, which downloads from this app's GitHub release).")
                    bullet("All your tiles live in ~/Library/Application Support/Bento/deck.json — you own them.")
                }

                section("About shell-command tiles") {
                    bullet("A shell tile runs whatever command you typed in the editor, in zsh, as your own user account.")
                    bullet("It can do anything you can do in Terminal — same powers, same limits.")
                    bullet("Bento never runs a shell command on your behalf except by firing one of YOUR tiles. Nothing inbound (URL scheme, CLI, hotkey) can run a command that wasn't already in your deck.")
                    bullet("⌘-click any tile to see the exact command before it runs.")
                    bullet("Be careful with tiles you imported from someone else's JSON — read the command first. Same trust model as installing any open-source script.")
                    bullet("Bento has no auto-update mechanism that could swap a safe command for a dangerous one — the deck only changes when you change it.")
                }

                section("How it works") {
                    bullet("Click any tile to fire its action.")
                    bullet("⌘-click a tile to edit it.")
                    bullet("Right-click a tile for Edit / Delete.")
                    bullet("Drag the panel anywhere on screen — it remembers across launches.")
                    bullet("⌃⌘B from any app shows or hides the panel.")
                    bullet("The X (red traffic-light) hides the panel — Bento stays in your Dock so the hotkey still works.")
                    bullet("To quit fully: ⌘Q, or App menu → Quit Bento.")
                }

                section("Your current tiles") {
                    ForEach(store.tiles) { tile in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: tile.symbol)
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06))
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tile.label)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Text(tile.info.isEmpty ? "(no description set — ⌘-click the tile to add one)" : tile.info)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                section("Add your own") {
                    bullet("Click the dashed + tile in the panel.")
                    bullet("Pick an icon, a label, and what the tile does.")
                    bullet("Three action types: launch an app (with a file picker), open a URL, or run a shell command.")
                    bullet("The shell action is the universal escape hatch — anything you can type in Terminal works.")
                }

                section("Drive Bento from elsewhere") {
                    Text("Two ways to fire a tile from outside the app — useful with Hammerspoon, Karabiner, Shortcuts, or Stream Deck Mobile:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    code("open 'bento://press/dark'")
                    code("bento press dark   # the bento CLI; install with ./scripts/install-cli.sh")
                }

                Spacer().frame(height: 8)
            }
            .padding(28)
        }
        .frame(minWidth: 540, minHeight: 460)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 28))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Bento")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("A minimal soft Stream Deck for macOS · v0.1.0")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            content()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·").font(.system(size: 13)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 12)).foregroundStyle(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func code(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
    }
}
