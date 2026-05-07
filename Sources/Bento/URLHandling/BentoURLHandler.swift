import Foundation

@MainActor
enum BentoURLHandler {
    static func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "bento" else { return }
        // Forms supported:
        //   bento://press/<id-or-slug>
        //   bento://confetti
        let host = url.host?.lowercased() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "press":
            guard let needle = pathComponents.first else { return }
            press(needle: needle)
        case "confetti":
            NotificationCenter.default.post(name: .bentoFireConfetti, object: nil)
        default:
            break
        }
    }

    static func press(needle: String) {
        guard let tile = DeckStore.shared.tile(byIDOrSlug: needle) else { return }
        Task {
            do {
                try await tile.action.execute()
                handleLiveSideEffect(tile: tile)
            } catch {
                NSLog("Bento: action error for \(tile.label): \(error)")
            }
        }
    }

    private static func handleLiveSideEffect(tile: Tile) {
        switch tile.liveKind {
        case .caffeinate:
            CaffeinateMonitor.shared.start(.caffeinate, durationSeconds: 3600)
        case .focus:
            CaffeinateMonitor.shared.start(.focus, durationSeconds: 1500)
        case .mic, .none:
            break
        }
    }
}

extension Notification.Name {
    static let bentoFireConfetti = Notification.Name("bento.fireConfetti")
    static let bentoTogglePanel = Notification.Name("bento.togglePanel")
    static let bentoPressTile = Notification.Name("bento.pressTile")
}
