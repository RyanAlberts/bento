import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let shared = PanelController()

    private var panel: NSPanel?
    private let positionKey = "BentoPanelPositionFraction"

    func showInitial() {
        if panel == nil { build() }
        positionPanel()
        panel?.orderFrontRegardless()
    }

    func toggle() {
        if panel == nil { build() }
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            positionPanel()
            panel.orderFrontRegardless()
        }
    }

    private func build() {
        // Tall enough for 8 default tiles + the "+" tile on a 3rd row + coachmark
        let initialSize = NSSize(width: 360, height: 320)
        let initialOrigin = NSPoint(x: 200, y: 200)
        let panel = BentoPanel(
            contentRect: NSRect(origin: initialOrigin, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.delegate = self

        let host = NSHostingView(
            rootView:
                DeckRootView()
                    .environmentObject(DeckStore.shared)
        )
        host.translatesAutoresizingMaskIntoConstraints = false

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(visualEffect)
        container.addSubview(host)
        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        panel.contentView = container
        self.panel = panel
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let saved = UserDefaults.standard.dictionary(forKey: positionKey) as? [String: Double]
        let xFrac = saved?["x"] ?? 0.5
        let yFrac = saved?["y"] ?? 0.5

        var origin = NSPoint(
            x: frame.minX + xFrac * frame.width  - panel.frame.width / 2,
            y: frame.minY + yFrac * frame.height - panel.frame.height / 2
        )
        // Clamp into visible bounds
        origin.x = min(max(frame.minX, origin.x), frame.maxX - panel.frame.width)
        origin.y = min(max(frame.minY, origin.y), frame.maxY - panel.frame.height)
        panel.setFrameOrigin(origin)
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.persistPosition()
        }
    }

    private func persistPosition() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let xFrac = (center.x - frame.minX) / frame.width
        let yFrac = (center.y - frame.minY) / frame.height
        UserDefaults.standard.set(["x": xFrac, "y": yFrac], forKey: positionKey)
    }
}

// NSPanel subclass needed because borderless panels otherwise refuse to become key.
final class BentoPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// Tiny wrapper so DeckView gets the confetti overlay layered on top.
struct DeckRootView: View {
    var body: some View {
        ZStack {
            DeckView()
            ConfettiView()
        }
    }
}
