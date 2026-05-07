import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TileEditor: View {
    let initial: Tile?
    let onSave: (Tile) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var symbol: String = ""
    @State private var tint: TileTint = .neutral
    @State private var actionKind: String = LaunchAppAction.kind  // file picker is the friendliest default
    @State private var payload: String = ""
    @State private var info: String = ""

    private struct ActionKindOption: Identifiable {
        let id: String
        let title: String
        let helpText: String
        let placeholder: String
    }

    private let kinds: [ActionKindOption] = [
        ActionKindOption(
            id: LaunchAppAction.kind,
            title: "Launch an app",
            // No helpText — the Choose… button is self-explanatory.
            helpText: "",
            placeholder: "/Applications/Calculator.app"
        ),
        ActionKindOption(
            id: OpenURLAction.kind,
            title: "Open a web page",
            helpText: "Any URL works — websites (https://), email (mailto:), or app schemes (raycast://, vscode://, even bento://press/<id>).",
            placeholder: "https://example.com"
        ),
        ActionKindOption(
            id: RunShellAction.kind,
            title: "Run a shell command",
            helpText: "Runs in zsh with your normal $PATH. Anything you can type in Terminal works — osascript, shortcuts run, hs, curl, etc.",
            placeholder: "open -a Calculator"
        ),
    ]

    private var currentKind: ActionKindOption {
        kinds.first { $0.id == actionKind } ?? kinds[0]
    }

    // Icon catalog the user picks from. Internally these are SF Symbol names;
    // the user never sees the names — just the icons themselves.
    private let symbolPresets: [String] = [
        "moon.fill", "sun.max.fill", "lock.fill", "mic.fill", "speaker.fill",
        "play.fill", "pause.fill", "calendar", "envelope.fill", "message.fill",
        "phone.fill", "video.fill", "camera.fill", "bolt.fill", "wifi",
        "cloud.fill", "music.note", "headphones", "bell.fill", "flag.fill",
        "star.fill", "heart.fill", "checkmark.circle.fill", "xmark.circle.fill",
        "arrow.clockwise", "trash.fill", "folder.fill", "doc.fill",
        "terminal.fill", "globe", "house.fill", "gearshape.fill",
        "cup.and.saucer.fill", "target", "moon.zzz.fill", "note.text",
        "eject.fill", "mic.slash.fill", "camera.viewfinder", "app.fill",
        "square.grid.2x2.fill", "rectangle.on.rectangle", "display",
        "battery.100", "powersleep", "command", "keyboard",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(initial == nil ? "New tile" : "Edit tile")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                livePreview
            }

            Form {
                Section {
                    TextField("Label", text: $label, prompt: Text("e.g. Coffee, Snap, Email"))
                        .help("Shown under the icon. One word reads best — limited space on the tile.")

                    HStack(spacing: 12) {
                        Text("Icon")
                            .frame(width: 80, alignment: .leading)
                        // Big visible swatch of the current icon
                        Image(systemName: symbol.trimmingCharacters(in: .whitespaces).isEmpty ? "square.dashed" : symbol)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.85))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06))
                            )
                        Spacer(minLength: 8)
                        Menu {
                            ForEach(symbolPresets, id: \.self) { name in
                                Button {
                                    symbol = name
                                } label: {
                                    // System catalog renders the symbol as the menu-item icon;
                                    // we don't show the raw name to the user.
                                    Image(systemName: name)
                                }
                            }
                            Divider()
                            Button("More icons on Apple's site…") {
                                NSWorkspace.shared.open(URL(string: "https://developer.apple.com/sf-symbols/")!)
                            }
                        } label: {
                            Text(symbol.trimmingCharacters(in: .whitespaces).isEmpty ? "Choose icon" : "Change icon")
                        }
                        .menuStyle(.borderedButton)
                        .fixedSize()
                    }
                    .help("Pick an icon for this tile.")

                    Picker("Color", selection: $tint) {
                        Text("Neutral").tag(TileTint.neutral)
                        Text("Accent").tag(TileTint.accent)
                        Text("Red").tag(TileTint.red)
                    }
                    .help("Color is reserved as signal — use Accent for state-changing tiles, Red for warnings.")
                } header: {
                    Text("Look")
                }

                Section {
                    Picker("Action", selection: $actionKind) {
                        ForEach(kinds) { kind in
                            Text(kind.title).tag(kind.id)
                        }
                    }

                    if actionKind == LaunchAppAction.kind {
                        // File-picker UX for app paths so users never have to type/paste
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            TextField("App", text: $payload, prompt: Text(currentKind.placeholder))
                                .font(.system(size: 12, design: .monospaced))
                                .disabled(true)
                                .foregroundStyle(payload.isEmpty ? .secondary : .primary)
                            Button("Choose…") {
                                pickApplication()
                            }
                            .keyboardShortcut("o", modifiers: [.command])
                        }
                    } else {
                        TextField(currentKind.title, text: $payload, prompt: Text(currentKind.placeholder), axis: .vertical)
                            .lineLimit(2...8)
                            .font(.system(size: 12, design: .monospaced))
                    }
                } header: {
                    Text("What this tile does")
                } footer: {
                    Text(currentKind.helpText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Section {
                    TextField("Tooltip", text: $info, prompt: Text("Shown when you hover the tile. Optional but recommended."), axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Description")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button(initial == nil ? "Add tile" : "Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || payload.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 540, height: 600)
        .onAppear { hydrate() }
    }

    private var livePreview: some View {
        HStack(spacing: 8) {
            Image(systemName: previewSymbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(previewColor)
            Text(label.isEmpty ? "—" : label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(previewBg)
        )
    }

    private var previewSymbol: String {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "square.fill" : trimmed
    }
    private var previewColor: Color {
        switch tint {
        case .accent: return .accentColor
        case .red:    return Color(nsColor: .systemRed)
        case .neutral: return .primary.opacity(0.8)
        }
    }
    private var previewBg: Color {
        switch tint {
        case .accent: return Color.accentColor.opacity(0.12)
        case .red:    return Color(nsColor: .systemRed).opacity(0.10)
        case .neutral: return Color.primary.opacity(0.06)
        }
    }

    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to launch from this tile"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        payload = url.path

        // Auto-fill the label from the .app's display name if the user hasn't typed one yet.
        if label.trimmingCharacters(in: .whitespaces).isEmpty {
            let bundle = Bundle(url: url)
            let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            label = displayName ?? bundleName ?? url.deletingPathExtension().lastPathComponent
        }
        // Suggest a sensible icon if the user hasn't picked one yet.
        if symbol.trimmingCharacters(in: .whitespaces).isEmpty {
            symbol = "app.fill"
        }
    }

    private func hydrate() {
        guard let initial else { return }
        label = initial.label
        symbol = initial.symbol
        tint = initial.tint
        actionKind = initial.action.kind
        payload = initial.action.payload
        info = initial.info
    }

    private func save() {
        // Fall back to a sane default symbol if the user left it blank.
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespaces)
        let finalSymbol = trimmedSymbol.isEmpty ? "square.fill" : trimmedSymbol

        let tile = Tile(
            id: initial?.id ?? UUID(),
            label: label.trimmingCharacters(in: .whitespaces),
            symbol: finalSymbol,
            tint: tint,
            action: AnyAction(kind: actionKind, payload: payload),
            liveKind: initial?.liveKind,
            info: info.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(tile)
        dismiss()
    }
}
