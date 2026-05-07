import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let shared = PanelController()

    private var window: NSWindow?
    private let positionKey = "BentoPanelPositionFraction"
    private let opacityKey = "BentoPanelOpacity"
    private var opacityObserver: NSObjectProtocol?

    override init() {
        super.init()
        // Listen for opacity changes from Preferences and apply live.
        opacityObserver = NotificationCenter.default.addObserver(
            forName: .bentoOpacityChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // Extract the value before crossing the actor boundary so Swift 6
            // strict concurrency doesn't choke on the non-Sendable Notification.
            let value = note.object as? Double
            Task { @MainActor [weak self] in
                if let value {
                    self?.applyOpacity(value)
                }
            }
        }
    }

    /// First-launch entry point. Builds the window if needed, positions it, and orders it front
    /// (which on a regular app activates Bento normally — Dock icon highlights, app menu appears).
    func showInitial() {
        if window == nil { build() }
        positionWindow()
        applyOpacity(currentOpacity())
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hotkey + menu toggle: shows the window if hidden (and brings Bento forward like Cmd+Tab),
    /// or hides it if visible. Hide does not quit — the app stays in the Dock.
    func toggle() {
        if window == nil { build() }
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            positionWindow()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func build() {
        // 28pt title bar + 2 rows of 76pt tiles + 8pt grid spacing + 12pt grid padding × 2
        // + ~36pt footer (Help button + coachmark) = ~280pt minimum.
        // 380pt gives plenty of slack so the Help button never clips on any display.
        let initialSize = NSSize(width: 360, height: 380)
        let initialOrigin = NSPoint(x: 200, y: 200)

        // Regular Mac window — gets the standard close/minimize/zoom traffic-light buttons,
        // participates in Mission Control, hot corners, Spaces, and Cmd+Tab. Not a HUD.
        let window = BentoWindow(
            contentRect: NSRect(origin: initialOrigin, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Bento"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // Default window level + collection behavior — behaves like Calculator, Things3 quick-entry, etc.
        window.level = .normal
        window.collectionBehavior = [.fullScreenAuxiliary]  // can show in fullscreen apps' overlay if user wants
        window.delegate = self
        // Min size enforced so the user can't shrink past where the footer (Help button +
        // coachmark) would clip. Width allows a slight squeeze for narrower screens.
        window.minSize = NSSize(width: 340, height: 360)

        // Glass material so the panel looks polished, but we no longer pretend to be a HUD.
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .windowBackground
        visualEffect.state = .followsWindowActiveState
        visualEffect.blendingMode = .behindWindow
        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        let host = NSHostingView(
            rootView:
                DeckRootView()
                    .environmentObject(DeckStore.shared)
        )
        host.translatesAutoresizingMaskIntoConstraints = false

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

        window.contentView = container
        self.window = window
    }

    private func positionWindow() {
        guard let window, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let saved = UserDefaults.standard.dictionary(forKey: positionKey) as? [String: Double]
        let xFrac = saved?["x"] ?? 0.5
        let yFrac = saved?["y"] ?? 0.5

        var origin = NSPoint(
            x: frame.minX + xFrac * frame.width  - window.frame.width / 2,
            y: frame.minY + yFrac * frame.height - window.frame.height / 2
        )
        // Clamp into visible bounds
        origin.x = min(max(frame.minX, origin.x), frame.maxX - window.frame.width)
        origin.y = min(max(frame.minY, origin.y), frame.maxY - window.frame.height)
        window.setFrameOrigin(origin)
    }

    // MARK: - NSWindowDelegate

    /// Clicking the X button HIDES the window instead of closing it. The app stays running
    /// in the Dock; ⌃⌘B (or clicking the Dock icon) brings it back.
    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        // NSWindowDelegate calls always come on the main thread; assumeIsolated
        // tells the compiler we know that, satisfying Swift 6 strict concurrency.
        MainActor.assumeIsolated {
            sender.orderOut(nil)
        }
        return false
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.persistPosition()
        }
    }

    private func persistPosition() {
        guard let window, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let xFrac = (center.x - frame.minX) / frame.width
        let yFrac = (center.y - frame.minY) / frame.height
        UserDefaults.standard.set(["x": xFrac, "y": yFrac], forKey: positionKey)
    }

    // MARK: - Opacity (Preferences-driven)

    private func currentOpacity() -> Double {
        let stored = UserDefaults.standard.double(forKey: opacityKey)
        return stored == 0 ? 1.0 : stored
    }

    private func applyOpacity(_ value: Double) {
        guard let window else { return }
        let clamped = max(0.4, min(1.0, value))
        window.alphaValue = CGFloat(clamped)
        // When the panel is transparent, dragging by the background gets weird:
        // clicks pass through to whatever's behind, and the user reports they
        // can't move it. We disable background-drag while transparent — the user
        // still has Preferences → Reset Panel Position to recenter.
        window.isMovableByWindowBackground = clamped >= 0.95
    }
}

/// Custom NSWindow subclass — kept so we can spot Bento's window via type-check
/// (NSApp.windows.first(where: { $0 is BentoWindow })).
final class BentoWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// Backwards-compat alias so existing references in BentoApp / fireConfetti compile
// without churn through every call site.
typealias BentoPanel = BentoWindow

// Tiny wrapper so DeckView gets the confetti overlay layered on top.
struct DeckRootView: View {
    var body: some View {
        ZStack {
            DeckView()
            ConfettiView()
        }
    }
}
