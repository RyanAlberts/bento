import SwiftUI
import AppKit

struct DeckView: View {
    @EnvironmentObject private var store: DeckStore
    @StateObject private var caffeinate = CaffeinateMonitor.shared
    @StateObject private var mic = MicMonitor.shared

    @State private var editingTile: Tile?
    @State private var showingAddSheet = false
    @State private var coachmarkVisible = !UserDefaults.standard.bool(forKey: "BentoCoachmarkSeen")

    /// Currently keyboard-focused cell. Indexed across [tiles..., addButton].
    /// Wraps row-by-row using `columns` (4 wide).
    @State private var focusedIndex: Int = 0
    @FocusState private var deckHasFocus: Bool

    private let columns = Array(repeating: GridItem(.fixed(76), spacing: 8), count: 4)

    private var totalCells: Int { store.tiles.count + 1 }   // tiles + the "+" button
    private var lastIndex: Int { totalCells - 1 }
    private var columnCount: Int { 4 }

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(store.tiles.enumerated()), id: \.element.id) { idx, tile in
                    TileView(
                        tile: tile,
                        isFocused: deckHasFocus && focusedIndex == idx,
                        onPress: { tile in
                            BentoURLHandler.press(needle: tile.id.uuidString)
                            dismissCoachmark()
                        },
                        onEdit: { editingTile = $0 },
                        onDelete: { store.delete(id: $0.id) }
                    )
                    .onTapGesture {
                        // Click also moves keyboard focus there.
                        focusedIndex = idx
                    }
                }
                AddTileButton(
                    isFocused: deckHasFocus && focusedIndex == store.tiles.count,
                    action: { showingAddSheet = true }
                )
            }
            .padding(12)

            // Footer: help button + coachmark caption
            HStack(spacing: 12) {
                Button {
                    NotificationCenter.default.post(name: .bentoOpenHelp, object: nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("Help")
                    }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open the Bento Help window — explains every tile and shows how to add your own.")

                Spacer()

                if coachmarkVisible {
                    Text("← → ↑ ↓ to navigate · ⏎ to fire · ⌘-click to edit")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .transition(.opacity)
                        .task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            await MainActor.run { dismissCoachmark() }
                        }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .environmentObject(caffeinate)
        .environmentObject(mic)
        .focusable()
        .focused($deckHasFocus)
        // Suppress the system's blue focus ring that wraps the whole deck —
        // we draw our own per-tile focus indicator (accent border + halo).
        .focusEffectDisabled()
        .onAppear {
            // Auto-focus the deck so arrow keys work without an extra click.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                deckHasFocus = true
            }
        }
        .onKeyPress(.leftArrow)  { moveFocus(by: -1) }
        .onKeyPress(.rightArrow) { moveFocus(by: 1) }
        .onKeyPress(.upArrow)    { moveFocus(by: -columnCount) }
        .onKeyPress(.downArrow)  { moveFocus(by: columnCount) }
        .onKeyPress(.return)     { fireFocused() }
        .onKeyPress(.space)      { fireFocused() }
        .sheet(isPresented: $showingAddSheet) {
            TileEditor(initial: nil) { newTile in
                store.add(newTile)
            }
        }
        .sheet(item: $editingTile) { tile in
            TileEditor(initial: tile) { updated in
                store.update(updated)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bentoOpenAddSheet)) { _ in
            showingAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .bentoOpenHelp)) { _ in
            NSApp.sendAction(Selector(("showHelp")), to: nil, from: nil)
        }
    }

    @discardableResult
    private func moveFocus(by delta: Int) -> KeyPress.Result {
        let candidate = focusedIndex + delta
        guard candidate >= 0, candidate < totalCells else { return .handled }
        focusedIndex = candidate
        return .handled
    }

    @discardableResult
    private func fireFocused() -> KeyPress.Result {
        guard !showingAddSheet, editingTile == nil else { return .ignored }
        if focusedIndex == store.tiles.count {
            // The "+" cell
            showingAddSheet = true
        } else if focusedIndex < store.tiles.count {
            let tile = store.tiles[focusedIndex]
            BentoURLHandler.press(needle: tile.id.uuidString)
            dismissCoachmark()
        }
        return .handled
    }

    private func dismissCoachmark() {
        guard coachmarkVisible else { return }
        withAnimation(.easeOut(duration: 0.4)) {
            coachmarkVisible = false
        }
        UserDefaults.standard.set(true, forKey: "BentoCoachmarkSeen")
    }
}

private struct AddTileButton: View {
    var isFocused: Bool = false
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.06 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isFocused ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.15),
                                style: StrokeStyle(lineWidth: isFocused ? 2 : 1, dash: isFocused ? [] : [3, 3])
                            )
                    )
                    .shadow(color: isFocused ? Color.accentColor.opacity(0.35) : .clear, radius: isFocused ? 6 : 0)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, height: 76)
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isFocused)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Add a new tile")
    }
}

extension Notification.Name {
    static let bentoOpenHelp = Notification.Name("bento.openHelp")
}
