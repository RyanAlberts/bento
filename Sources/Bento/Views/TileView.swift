import SwiftUI
import AppKit

struct TileView: View {
    let tile: Tile
    let onPress: (Tile) -> Void
    let onEdit: (Tile) -> Void
    let onDelete: (Tile) -> Void

    @EnvironmentObject private var caffeinate: CaffeinateMonitor
    @EnvironmentObject private var mic: MicMonitor

    @State private var pressed = false
    @State private var hovering = false
    @State private var errorFlash = false

    private var isLiveActive: Bool {
        switch tile.liveKind {
        case .caffeinate: return caffeinate.assertion(for: .caffeinate) != nil
        case .focus:      return caffeinate.assertion(for: .focus) != nil
        case .mic:        return mic.isMuted
        case .none:       return false
        }
    }

    private var ringFraction: Double? {
        switch tile.liveKind {
        case .caffeinate: return caffeinate.assertion(for: .caffeinate)?.elapsedFraction
        case .focus:      return caffeinate.assertion(for: .focus)?.elapsedFraction
        default:          return nil
        }
    }

    private var effectiveTint: TileTint {
        if errorFlash { return .red }
        if tile.liveKind == .mic && mic.isMuted { return .red }
        if isLiveActive && tile.tint == .accent { return .accent }
        return tile.tint
    }

    private var fgColor: Color {
        switch effectiveTint {
        case .neutral: return Color.primary.opacity(0.78)
        case .accent:  return Color.accentColor
        case .red:     return Color(nsColor: .systemRed)
        }
    }

    private var bgColor: Color {
        switch effectiveTint {
        case .accent: return Color.accentColor.opacity(0.14)
        case .red:    return Color(nsColor: .systemRed).opacity(0.12)
        case .neutral: return Color.primary.opacity(hovering ? 0.06 : 0.03)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            if let frac = ringFraction {
                Circle()
                    .trim(from: 0, to: max(0.001, frac))
                    .stroke(Color.accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)
                    .animation(.linear(duration: 1), value: frac)
            }

            VStack(spacing: 6) {
                Image(systemName: tile.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(fgColor)
                Text(tile.label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(fgColor.opacity(0.95))
                    .lineLimit(1)
            }
        }
        .frame(width: 76, height: 76)
        .scaleEffect(pressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.55), value: pressed)
        .onHover { hovering = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            // ⌘-click → edit
            if NSEvent.modifierFlags.contains(.command) {
                onEdit(tile)
                return
            }
            firePress()
        }
        .contextMenu {
            Button("Edit") { onEdit(tile) }
            Button("Delete", role: .destructive) { onDelete(tile) }
        }
        .help(tile.label)
    }

    private func firePress() {
        pressed = true
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run { pressed = false }
        }
        onPress(tile)
    }
}
