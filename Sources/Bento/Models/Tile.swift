import Foundation

struct Tile: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var symbol: String
    var tint: TileTint
    var action: AnyAction
    var liveKind: LiveKind?

    init(
        id: UUID = UUID(),
        label: String,
        symbol: String,
        tint: TileTint = .neutral,
        action: AnyAction,
        liveKind: LiveKind? = nil
    ) {
        self.id = id
        self.label = label
        self.symbol = symbol
        self.tint = tint
        self.action = action
        self.liveKind = liveKind
    }

    var slug: String {
        label
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

enum TileTint: String, Codable, Hashable {
    case neutral
    case accent
    case red
}

enum LiveKind: String, Codable, Hashable {
    case caffeinate
    case focus
    case mic
}
