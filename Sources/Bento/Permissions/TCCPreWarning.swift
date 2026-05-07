import Foundation
import AppKit

enum TCCPreWarning {
    private static let key = "TCCPreWarningShown"

    static var hasShown: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func showIfNeeded() {
        guard !hasShown else { return }
        let alert = NSAlert()
        alert.messageText = "Welcome to Bento."
        alert.informativeText = """
        Some default tiles (Dark, Eject, Mic) use macOS Automation. The first time you press one of those tiles, macOS will ask permission.

        Click Allow on each prompt — there are 2.

        Custom tiles you build with shell commands or app launches don't trigger any prompt.
        """
        alert.addButton(withTitle: "Got it")
        alert.alertStyle = .informational
        alert.runModal()
        UserDefaults.standard.set(true, forKey: key)
    }
}
