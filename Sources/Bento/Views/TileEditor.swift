import SwiftUI
import AppKit

struct TileEditor: View {
    let initial: Tile?
    let onSave: (Tile) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var symbol: String = "square.fill"
    @State private var tint: TileTint = .neutral
    @State private var actionKind: String = RunShellAction.kind
    @State private var payload: String = ""
    @State private var info: String = ""
    @State private var showSymbolHelp = false

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
            helpText: "Paste the full path to a .app, or drag one in from Finder.",
            placeholder: "/Applications/Calculator.app"
        ),
        ActionKindOption(
            id: OpenURLAction.kind,
            title: "Open a link",
            helpText: "Any URL works — websites, mailto:, raycast://, vscode://, even bento://press/<id>.",
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(initial == nil ? "New tile" : "Edit tile")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                if initial != nil {
                    livePreview
                }
            }

            Form {
                Section {
                    TextField("Label", text: $label, prompt: Text("e.g. Coffee, Snap, Email"))
                        .help("Shown under the icon. One word reads best — limited space on the tile.")

                    HStack {
                        TextField("Icon", text: $symbol, prompt: Text("e.g. moon.fill"))
                            .help("Any SF Symbol name. Browse the catalog at developer.apple.com/sf-symbols.")
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://developer.apple.com/sf-symbols/")!)
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Open the SF Symbols catalog in your browser to find an icon name.")
                    }

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

                    Text(currentKind.helpText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -4)

                    TextField(currentKind.title, text: $payload, prompt: Text(currentKind.placeholder), axis: .vertical)
                        .lineLimit(2...8)
                        .font(.system(size: 12, design: .monospaced))
                } header: {
                    Text("What this tile does")
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
        .frame(width: 520, height: 580)
        .onAppear { hydrate() }
    }

    private var livePreview: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol.isEmpty ? "square.fill" : symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))
            Text(label.isEmpty ? "—" : label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06))
        )
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
        let tile = Tile(
            id: initial?.id ?? UUID(),
            label: label.trimmingCharacters(in: .whitespaces),
            symbol: symbol.trimmingCharacters(in: .whitespaces),
            tint: tint,
            action: AnyAction(kind: actionKind, payload: payload),
            liveKind: initial?.liveKind,
            info: info.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(tile)
        dismiss()
    }
}
