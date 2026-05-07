import AppKit
import SwiftUI

// Bento intentionally drives the lifecycle from an NSApplicationDelegate
// (not SwiftUI's @main App + WindowGroup) so we can fully control the window
// behavior — title bar, level, collection behavior, close-hides-not-quits.

@main
enum BentoMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // .regular = Dock icon, app switcher entry, standard menu bar at top of screen.
        // The window participates in Mission Control, hot corners, Spaces like any normal app.
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var watcher: DeckWatcher?
    private var helpWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        TCCPreWarning.showIfNeeded()
        installAppMenu()
        installStatusBarItem()
        installURLHandler()
        installNotifications()
        GlobalHotkey.shared.register()
        startWatcher()
        PanelController.shared.showInitial()
    }

    /// Re-show the window when the user clicks the Dock icon while no Bento windows are visible.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            PanelController.shared.showInitial()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkey.shared.unregister()
    }

    // MARK: - Standard macOS menu bar

    /// Builds the App / File / Edit / View / Window / Help menus you see at the top of the
    /// screen when Bento is the foreground app.
    private func installAppMenu() {
        let main = NSMenu()

        // Bento (App) menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Bento", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide Bento", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Bento", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        main.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "New Tile…", action: #selector(newTileFromMenu), keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Open deck.json Folder", action: #selector(openDeckFolder), keyEquivalent: ""))
        fileMenu.addItem(NSMenuItem(title: "Reveal Bento.app in Finder", action: #selector(revealApp), keyEquivalent: ""))
        fileMenu.addItem(NSMenuItem.separator())
        let close = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(close)
        fileMenuItem.submenu = fileMenu
        main.addItem(fileMenuItem)

        // Edit menu (so Cmd+C / Cmd+V / undo work in the tile editor sheet)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        main.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let toggleVis = NSMenuItem(title: "Show / Hide Panel", action: #selector(togglePanel), keyEquivalent: "b")
        toggleVis.keyEquivalentModifierMask = [.control, .command]
        viewMenu.addItem(toggleVis)
        viewMenu.addItem(NSMenuItem(title: "Reset Panel Position", action: #selector(resetPosition), keyEquivalent: ""))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Confetti 🎉", action: #selector(fireConfetti), keyEquivalent: ""))
        viewMenuItem.submenu = viewMenu
        main.addItem(viewMenuItem)

        // Window menu (standard macOS)
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        windowMenuItem.submenu = windowMenu
        main.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        // Help menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(NSMenuItem(title: "Bento Help", action: #selector(showHelp), keyEquivalent: "?"))
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(NSMenuItem(title: "Open Recipes on GitHub", action: #selector(openRecipes), keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem(title: "Report an Issue", action: #selector(reportIssue), keyEquivalent: ""))
        helpMenuItem.submenu = helpMenu
        main.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = main
    }

    // MARK: - Status bar item (still useful as a quick toggle)

    private func installStatusBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Bento")
            button.toolTip = "Bento — click for menu (⌃⌘B to toggle the panel)"
        }
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Show / Hide Panel", action: #selector(togglePanel), keyEquivalent: "b")
        toggle.keyEquivalentModifierMask = [.control, .command]
        menu.addItem(toggle)
        menu.addItem(NSMenuItem(title: "Bento Help…", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Bento", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    // MARK: - Actions

    @objc private func togglePanel() { PanelController.shared.toggle() }

    @objc private func newTileFromMenu() {
        PanelController.shared.showInitial()
        NotificationCenter.default.post(name: .bentoOpenAddSheet, object: nil)
    }

    @objc private func resetPosition() {
        UserDefaults.standard.removeObject(forKey: "BentoPanelPositionFraction")
        PanelController.shared.showInitial()
    }

    @objc private func fireConfetti() {
        NotificationCenter.default.post(name: .bentoFireConfetti, object: nil)
        if let panel = NSApp.windows.first(where: { $0 is BentoWindow }), !panel.isVisible {
            PanelController.shared.toggle()
        }
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Bento",
            .applicationVersion: "0.1.0",
            .credits: NSAttributedString(string: "A minimal, fun, open-source soft Stream Deck for macOS.\n\ngithub.com/RyanAlberts/bento"),
        ])
    }

    @objc private func showHelp() {
        if helpWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 540),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Bento Help"
            win.center()
            win.isReleasedWhenClosed = false
            win.contentView = NSHostingView(rootView: HelpView())
            helpWindow = win
        }
        helpWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showPreferences() {
        if preferencesWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "Bento Preferences"
            win.center()
            win.isReleasedWhenClosed = false
            win.contentView = NSHostingView(rootView: PreferencesView())
            preferencesWindow = win
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openDeckFolder() {
        let url = DeckStore.shared.configFileURL.deletingLastPathComponent()
        NSWorkspace.shared.open(url)
    }

    @objc private func revealApp() {
        let path = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([path])
    }

    @objc private func openRecipes() {
        if let url = URL(string: "https://github.com/RyanAlberts/bento/tree/main/recipes") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func reportIssue() {
        if let url = URL(string: "https://github.com/RyanAlberts/bento/issues/new") {
            NSWorkspace.shared.open(url)
        }
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

        DistributedNotificationCenter.default().addObserver(
            forName: .bentoPressTile,
            object: nil,
            queue: .main
        ) { note in
            if let needle = note.userInfo?["needle"] as? String {
                Task { @MainActor in BentoURLHandler.press(needle: needle) }
            }
        }

        // Preferences-driven actions
        NotificationCenter.default.addObserver(
            forName: .bentoResetPosition,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                UserDefaults.standard.removeObject(forKey: "BentoPanelPositionFraction")
                PanelController.shared.showInitial()
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

extension Notification.Name {
    static let bentoOpenAddSheet = Notification.Name("bento.openAddSheet")
}
