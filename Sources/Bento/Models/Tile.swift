import Foundation

struct Tile: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var symbol: String
    var tint: TileTint
    var action: AnyAction
    var liveKind: LiveKind?
    var info: String        // one-line plain-English description, shown in tooltip + Help screen

    init(
        id: UUID = UUID(),
        label: String,
        symbol: String,
        tint: TileTint = .neutral,
        action: AnyAction,
        liveKind: LiveKind? = nil,
        info: String = ""
    ) {
        self.id = id
        self.label = label
        self.symbol = symbol
        self.tint = tint
        self.action = action
        self.liveKind = liveKind
        self.info = info
    }

    // Forward-compat decoder so existing deck.json files (without `info`) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        symbol = try c.decode(String.self, forKey: .symbol)
        tint = try c.decode(TileTint.self, forKey: .tint)
        action = try c.decode(AnyAction.self, forKey: .action)
        liveKind = try c.decodeIfPresent(LiveKind.self, forKey: .liveKind)
        info = try c.decodeIfPresent(String.self, forKey: .info) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, symbol, tint, action, liveKind, info
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
