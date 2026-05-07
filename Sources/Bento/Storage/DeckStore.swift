import Foundation

@MainActor
final class DeckStore: ObservableObject {
    @Published private(set) var tiles: [Tile] = []
    private let url: URL
    private let schemaVersion: Int = 1

    static let shared = DeckStore()

    init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("Bento", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.url = dir.appendingPathComponent("deck.json")
        }
        load()
    }

    var configFileURL: URL { url }

    func load() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            tiles = DefaultDeck.tiles
            save()
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder().decode(DeckEnvelope.self, from: data)
            // Schema migration stub: v1 → v1 is identity. Future bumps slot in here.
            tiles = envelope.tiles
        } catch {
            // Corrupted file → backup + reseed defaults so the user is never tile-less
            let backup = url.deletingPathExtension().appendingPathExtension("corrupted.\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            tiles = DefaultDeck.tiles
            save()
        }
    }

    func save() {
        let envelope = DeckEnvelope(schemaVersion: schemaVersion, tiles: tiles)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(envelope)
            try data.write(to: url, options: [.atomic])
        } catch {
            NSLog("Bento: failed to save deck: \(error)")
        }
    }

    func add(_ tile: Tile) {
        tiles.append(tile)
        save()
    }

    func update(_ tile: Tile) {
        if let i = tiles.firstIndex(where: { $0.id == tile.id }) {
            tiles[i] = tile
            save()
        }
    }

    func delete(id: UUID) {
        tiles.removeAll { $0.id == id }
        save()
    }

    func tile(byIDOrSlug needle: String) -> Tile? {
        if let uuid = UUID(uuidString: needle), let t = tiles.first(where: { $0.id == uuid }) {
            return t
        }
        let lower = needle.lowercased()
        return tiles.first { $0.slug == lower || $0.label.lowercased() == lower }
    }
}

private struct DeckEnvelope: Codable {
    var schemaVersion: Int
    var tiles: [Tile]
}
