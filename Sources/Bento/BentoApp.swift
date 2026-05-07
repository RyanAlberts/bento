import AppKit
import SwiftUI

// Bento intentionally does NOT use SwiftUI's @main App lifecycle because
// `WindowGroup` cannot produce a `.nonactivatingPanel`. We drive everything
// from an NSApplicationDelegate instead.

@main
enum BentoMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var watcher: DeckWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        TCCPreWarning.showIfNeeded()
        installMenuBar()
        installURLHandler()
        installNotifications()
        GlobalHotkey.shared.register()
        startWatcher()
        PanelController.shared.showInitial()
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkey.shared.unregister()
    }

    private func installMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Bento")
            button.toolTip = "Bento — click for menu (⌃⌘B to toggle the panel)"
        }

        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Show / Hide Panel", action: #selector(togglePanel), keyEquivalent: "b")
        toggle.keyEquivalentModifierMask = [.control, .command]
        menu.addItem(toggle)
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Confetti 🎉", action: #selector(fireConfetti), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open deck.json folder", action: #selector(openDeckFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About Bento", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Bento", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func togglePanel() { PanelController.shared.toggle() }

    @objc private func resetPosition() {
        UserDefaults.standard.removeObject(forKey: "BentoPanelPositionFraction")
        PanelController.shared.showInitial()
    }

    @objc private func fireConfetti() {
        NotificationCenter.default.post(name: .bentoFireConfetti, object: nil)
        if let panel = NSApp.windows.first(where: { $0 is BentoPanel }), !panel.isVisible {
            PanelController.shared.toggle()
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Bento 0.1.0"
        alert.informativeText = """
        A minimal soft Stream Deck for macOS.

        • Toggle the panel: ⌃⌘B
        • Add a tile: click the + in the panel
        • Edit a tile: ⌘-click it
        • Quit: this menu → Quit Bento

        github.com/ryan-alberts/bento
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openDeckFolder() {
        let url = DeckStore.shared.configFileURL.deletingLastPathComponent()
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func installURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        BentoURLHandler.handle(url)
    }

    private func installNotifications() {
        // Hotkey toggle
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(togglePanel),
            name: .bentoTogglePanel,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(togglePanel),
            name: .bentoTogglePanel,
            object: nil
        )

        // CLI-driven press
        DistributedNotificationCenter.default().addObserver(
            forName: .bentoPressTile,
            object: nil,
            queue: .main
        ) { note in
            if let needle = note.userInfo?["needle"] as? String {
                Task { @MainActor in BentoURLHandler.press(needle: needle) }
            }
        }
    }

    private func startWatcher() {
        let url = DeckStore.shared.configFileURL
        let watcher = DeckWatcher(url: url) {
            DeckStore.shared.load()
        }
        watcher.start()
        self.watcher = watcher
    }
}
