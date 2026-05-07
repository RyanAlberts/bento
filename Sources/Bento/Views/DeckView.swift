import SwiftUI

struct DeckView: View {
    @EnvironmentObject private var store: DeckStore
    @StateObject private var caffeinate = CaffeinateMonitor.shared
    @StateObject private var mic = MicMonitor.shared

    @State private var editingTile: Tile?
    @State private var showingAddSheet = false
    @State private var coachmarkVisible = !UserDefaults.standard.bool(forKey: "BentoCoachmarkSeen")

    private let columns = Array(repeating: GridItem(.fixed(76), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.tiles) { tile in
                    TileView(
                        tile: tile,
                        onPress: { tile in
                            BentoURLHandler.press(needle: tile.id.uuidString)
                            dismissCoachmark()
                        },
                        onEdit: { editingTile = $0 },
                        onDelete: { store.delete(id: $0.id) }
                    )
                }
                AddTileButton(action: { showingAddSheet = true })
            }
            .padding(12)

            if coachmarkVisible {
                Text("click to run · ⌘-click to edit · drag to move · ⌃⌘B to toggle")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        await MainActor.run { dismissCoachmark() }
                    }
            }
        }
        .environmentObject(caffeinate)
        .environmentObject(mic)
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
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.06 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, height: 76)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Add tile")
    }
}
