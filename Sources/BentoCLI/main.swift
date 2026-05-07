import Foundation

// `bento` CLI — talks to the running Bento.app via Distributed Notifications.
// Subcommands: press <id-or-label> | list | doctor | export | import

let args = Array(CommandLine.arguments.dropFirst())

guard let cmd = args.first else {
    printUsage()
    exit(0)
}

switch cmd {
case "press":
    guard let needle = args.dropFirst().first else {
        FileHandle.standardError.write(Data("usage: bento press <id-or-label>\n".utf8))
        exit(2)
    }
    DistributedNotificationCenter.default().post(
        name: Notification.Name("bento.pressTile"),
        object: nil,
        userInfo: ["needle": needle]
    )
case "toggle":
    DistributedNotificationCenter.default().post(name: Notification.Name("bento.togglePanel"), object: nil)
case "list":
    cmdList()
case "doctor":
    cmdDoctor()
case "export":
    cmdExport()
case "import":
    cmdImport()
case "--version", "-v":
    print("bento 0.1.1")
case "--help", "-h", "help":
    printUsage()
default:
    FileHandle.standardError.write(Data("Unknown subcommand: \(cmd)\n".utf8))
    printUsage()
    exit(2)
}

func printUsage() {
    print("""
    bento 0.1.1 — minimal soft Stream Deck for macOS

    Usage:
      bento press <id-or-label>   Fire a tile by ID or label
      bento toggle                Show or hide the panel
      bento list                  List all tiles
      bento doctor                Print config + status diagnostics
      bento export                Print deck.json to stdout
      bento import                Replace deck.json with stdin
      bento --version             Print version
    """)
}

func deckPath() -> URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return support.appendingPathComponent("Bento/deck.json")
}

func cmdList() {
    let path = deckPath()
    guard let data = try? Data(contentsOf: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tiles = json["tiles"] as? [[String: Any]] else {
        FileHandle.standardError.write(Data("No deck found at \(path.path)\n".utf8))
        exit(1)
    }
    for (i, t) in tiles.enumerated() {
        let label = t["label"] as? String ?? "?"
        let symbol = t["symbol"] as? String ?? "?"
        let id = (t["id"] as? String) ?? "?"
        print("\(i + 1). \(label.padding(toLength: 12, withPad: " ", startingAt: 0)) [\(symbol)]  \(id)")
    }
}

func cmdDoctor() {
    let path = deckPath()
    print("Bento CLI 0.1.1")
    print("Config:    \(path.path)")
    print("Exists:    \(FileManager.default.fileExists(atPath: path.path) ? "yes" : "no — will be created on first launch")")
    if let data = try? Data(contentsOf: path),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let tiles = json["tiles"] as? [[String: Any]] {
        print("Tiles:     \(tiles.count)")
        if let v = json["schemaVersion"] as? Int {
            print("Schema:    v\(v)")
        }
    }
    let appPath = "/Applications/Bento.app"
    print("App:       \(FileManager.default.fileExists(atPath: appPath) ? "/Applications/Bento.app present" : "not installed in /Applications")")
}

func cmdExport() {
    let path = deckPath()
    if let data = try? Data(contentsOf: path) {
        FileHandle.standardOutput.write(data)
    } else {
        FileHandle.standardError.write(Data("No deck to export at \(path.path)\n".utf8))
        exit(1)
    }
}

func cmdImport() {
    let path = deckPath()
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard !data.isEmpty else {
        FileHandle.standardError.write(Data("Stdin was empty — nothing to import\n".utf8))
        exit(2)
    }
    do {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: path, options: .atomic)
        print("Imported \(data.count) bytes into \(path.path)")
    } catch {
        FileHandle.standardError.write(Data("Import failed: \(error)\n".utf8))
        exit(1)
    }
}
