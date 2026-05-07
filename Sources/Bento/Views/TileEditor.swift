import SwiftUI

struct TileEditor: View {
    let initial: Tile?
    let onSave: (Tile) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var symbol: String = "square.fill"
    @State private var tint: TileTint = .neutral
    @State private var actionKind: String = RunShellAction.kind
    @State private var payload: String = ""

    private let kinds: [(String, String)] = [
        (RunShellAction.kind, "Run shell command"),
        (LaunchAppAction.kind, "Launch app (path to .app)"),
        (OpenURLAction.kind, "Open URL"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(initial == nil ? "New tile" : "Edit tile")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Form {
                TextField("Label (one word reads best)", text: $label)
                TextField("SF Symbol (e.g. moon.fill)", text: $symbol)
                Picker("Tint", selection: $tint) {
                    Text("Neutral").tag(TileTint.neutral)
                    Text("Accent").tag(TileTint.accent)
                    Text("Red").tag(TileTint.red)
                }
                Picker("Action", selection: $actionKind) {
                    ForEach(kinds, id: \.0) { kind, title in
                        Text(title).tag(kind)
                    }
                }
                TextField(payloadPlaceholder, text: $payload, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)

            HStack {
                if initial != nil {
                    Button("Cancel", role: .cancel) { dismiss() }
                } else {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                Spacer()
                Button(initial == nil ? "Add" : "Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || payload.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { hydrate() }
    }

    private var payloadPlaceholder: String {
        switch actionKind {
        case LaunchAppAction.kind: return "/Applications/Calculator.app"
        case OpenURLAction.kind:   return "https://example.com"
        default:                   return "echo hello"
        }
    }

    private func hydrate() {
        guard let initial else { return }
        label = initial.label
        symbol = initial.symbol
        tint = initial.tint
        actionKind = initial.action.kind
        payload = initial.action.payload
    }

    private func save() {
        let tile = Tile(
            id: initial?.id ?? UUID(),
            label: label.trimmingCharacters(in: .whitespaces),
            symbol: symbol.trimmingCharacters(in: .whitespaces),
            tint: tint,
            action: AnyAction(kind: actionKind, payload: payload),
            liveKind: initial?.liveKind
        )
        onSave(tile)
        dismiss()
    }
}
