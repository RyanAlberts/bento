import Foundation

// `bento` CLI — talks to the running Bento.app via Distributed Notifications.
// Subcommands: press <id-or-label> | toggle | list | doctor | export | import
//
// The CLI ↔ App boundary uses an ack round-trip (per /autoplan Eng F6):
// `press` posts a request with a unique replyTo UUID, then waits up to 2s for
// `bento.pressTile.ack.<uuid>`. On timeout, the CLI auto-launches Bento.app and
// retries once. On second timeout, it exits non-zero with a clear error so
// integrations (Hammerspoon, Karabiner, Shortcuts) get a real signal instead of
// silently no-opping.

let CLI_VERSION = "0.1.1"

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
    let exitCode = pressWithAck(needle: needle)
    exit(exitCode)
case "toggle":
    DistributedNotificationCenter.default().post(name: Notification.Name("bento.togglePanel"), object: nil)
case "list":
    cmdList(flags: Set(args.dropFirst()))
case "doctor":
    cmdDoctor(flags: Set(args.dropFirst()))
case "export":
    cmdExport()
case "import":
    cmdImport()
case "--version", "-v":
    if Set(args).contains("--json") {
        let dict: [String: Any] = ["bento_cli": CLI_VERSION]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            print(s)
        }
    } else {
        print("bento \(CLI_VERSION)")
    }
case "--help", "-h", "help":
    printUsage()
default:
    FileHandle.standardError.write(Data("Unknown subcommand: \(cmd). Run `bento --help` for usage. Docs: https://github.com/RyanAlberts/bento\n".utf8))
    exit(2)
}

func printUsage() {
    print("""
    bento \(CLI_VERSION) — minimal soft Stream Deck for macOS

    Usage:
      bento press <id-or-label>   Fire a tile by ID or label
      bento toggle                Show or hide the panel
      bento list [--json|--ids]   List all tiles (machine-readable with --json or one ID per line with --ids)
      bento doctor [--json]       Print config + status diagnostics
      bento export                Print deck.json to stdout
      bento import                Replace deck.json with stdin
      bento --version [--json]    Print version

    Env vars:
      BENTO_SUPPRESS_VERSION_CHECK=1   Silence the npm/app version-drift warning
    """)
}

func deckPath() -> URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return support.appendingPathComponent("Bento/deck.json")
}

// Press with ack round-trip (Eng F6). Returns CLI exit code.
func pressWithAck(needle: String) -> Int32 {
    if performPressOnce(needle: needle, attempt: 1) {
        return 0
    }
    // First attempt timed out — try to launch Bento.app then retry once.
    let launched = launchBentoApp()
    if launched {
        // Give Bento a moment to install its DistributedNotificationCenter observer.
        usleep(500_000) // 0.5s
        if performPressOnce(needle: needle, attempt: 2) {
            return 0
        }
    }
    FileHandle.standardError.write(Data(
        "bento: app did not acknowledge press for tile \"\(needle)\" within 2s. Is Bento.app running? Try `open -a Bento` or check that the tile exists with `bento list`.\n".utf8
    ))
    return 1
}

func performPressOnce(needle: String, attempt: Int) -> Bool {
    let replyTo = UUID().uuidString
    let ackName = Notification.Name("bento.pressTile.ack.\(replyTo)")
    let semaphore = DispatchSemaphore(value: 0)
    var acked = false

    let token = DistributedNotificationCenter.default().addObserver(
        forName: ackName,
        object: nil,
        queue: nil
    ) { _ in
        acked = true
        semaphore.signal()
    }

    DistributedNotificationCenter.default().post(
        name: Notification.Name("bento.pressTile"),
        object: nil,
        userInfo: ["needle": needle, "replyTo": replyTo]
    )

    let result = semaphore.wait(timeout: .now() + 2.0)
    DistributedNotificationCenter.default().removeObserver(token)
    return result == .success && acked
}

func launchBentoApp() -> Bool {
    let candidates = [
        "/Applications/Bento.app",
        ("\(NSHomeDirectory())/Applications/Bento.app"),
    ]
    for path in candidates {
        if FileManager.default.fileExists(atPath: path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-g", "-a", path]
            do {
                try process.run()
                return true
            } catch {
                continue
            }
        }
    }
    return false
}

// ---------- list ----------

func cmdList(flags: Set<String>) {
    let path = deckPath()
    guard let data = try? Data(contentsOf: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tiles = json["tiles"] as? [[String: Any]] else {
        FileHandle.standardError.write(Data("No deck found at \(path.path). Will be created on first launch of Bento.app.\n".utf8))
        exit(1)
    }

    if flags.contains("--json") {
        if let outData = try? JSONSerialization.data(withJSONObject: tiles, options: [.prettyPrinted]),
           let s = String(data: outData, encoding: .utf8) {
            print(s)
        }
        return
    }

    if flags.contains("--ids") {
        for t in tiles {
            if let id = t["id"] as? String { print(id) }
        }
        return
    }

    // Default: human-readable
    for (i, t) in tiles.enumerated() {
        let label = t["label"] as? String ?? "?"
        let symbol = t["symbol"] as? String ?? "?"
        let id = (t["id"] as? String) ?? "?"
        print("\(i + 1). \(label.padding(toLength: 12, withPad: " ", startingAt: 0)) [\(symbol)]  \(id)")
    }
}

// ---------- doctor (Phase 2 D4 spec) ----------

func cmdDoctor(flags: Set<String>) {
    let report = buildDoctorReport()

    if flags.contains("--json") {
        if let data = try? JSONSerialization.data(withJSONObject: report.asDict, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            print(s)
        }
        if report.hasFailures { exit(1) }
        return
    }

    printDoctorReport(report)
    if report.hasFailures { exit(1) }
}

struct DoctorReport {
    struct Row { let key: String; let value: String; let severity: String? }
    struct Section { let title: String; let rows: [Row] }
    let sections: [Section]
    var hasFailures: Bool {
        sections.contains { $0.rows.contains { $0.severity == "fail" } }
    }
    var asDict: [String: Any] {
        var out: [String: Any] = [:]
        for s in sections {
            var rows: [[String: Any]] = []
            for r in s.rows {
                var rd: [String: Any] = ["key": r.key, "value": r.value]
                if let sev = r.severity { rd["severity"] = sev }
                rows.append(rd)
            }
            out[s.title.lowercased()] = rows
        }
        out["pass"] = !hasFailures
        return out
    }
}

func buildDoctorReport() -> DoctorReport {
    let path = deckPath()
    let appPath = "/Applications/Bento.app"
    let homeAppPath = "\(NSHomeDirectory())/Applications/Bento.app"

    // Resolve installed app + its plist version
    let installPath: String
    let installExists: Bool
    if FileManager.default.fileExists(atPath: appPath) {
        installPath = appPath; installExists = true
    } else if FileManager.default.fileExists(atPath: homeAppPath) {
        installPath = homeAppPath; installExists = true
    } else {
        installPath = "(not installed)"; installExists = false
    }

    let installedVersion: String = {
        guard installExists else { return "(not installed)" }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/libexec/PlistBuddy")
        p.arguments = ["-c", "Print :CFBundleShortVersionString", "\(installPath)/Contents/Info.plist"]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "(unknown)"
        } catch { return "(unknown)" }
    }()

    // Signature type
    let signature: (String, String?) = {
        guard installExists else { return ("(not installed)", nil) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        p.arguments = ["--display", "--verbose=2", installPath]
        let pipe = Pipe()
        p.standardError = pipe
        p.standardOutput = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            if text.contains("Developer ID Application") { return ("Developer-ID-signed", "ok") }
            if text.contains("Authority=(unknown)") || text.contains("adhoc") { return ("ad-hoc (not Developer-ID-signed)", "info") }
            return (text.contains("Authority=") ? "signed (other)" : "unsigned", "info")
        } catch { return ("(could not check)", "info") }
    }()

    // CLI symlink resolution
    let cliSymlinkInfo: String = {
        for candidate in ["/usr/local/bin/bento", "\(NSHomeDirectory())/.local/bin/bento"] {
            if FileManager.default.fileExists(atPath: candidate) {
                if let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: candidate) {
                    return "\(candidate) → \(dest)"
                }
                return candidate
            }
        }
        return "(not symlinked)"
    }()

    // Deck info
    var tilesCount = 0
    var schemaVersion: Int? = nil
    if let data = try? Data(contentsOf: path),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let tiles = json["tiles"] as? [[String: Any]] { tilesCount = tiles.count }
        if let v = json["schemaVersion"] as? Int { schemaVersion = v }
    }

    // OS info
    let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    let arch: String = {
        var sysinfo = utsname()
        uname(&sysinfo)
        return withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }()

    var sections: [DoctorReport.Section] = []

    sections.append(DoctorReport.Section(title: "System", rows: [
        DoctorReport.Row(key: "OS", value: osVersion, severity: nil),
        DoctorReport.Row(key: "Arch", value: arch, severity: nil),
    ]))

    sections.append(DoctorReport.Section(title: "Install", rows: [
        DoctorReport.Row(key: "Bundle path", value: installPath, severity: installExists ? "ok" : "fail"),
        DoctorReport.Row(key: "CLI symlink", value: cliSymlinkInfo, severity: cliSymlinkInfo == "(not symlinked)" ? "warn" : "ok"),
        DoctorReport.Row(key: "Signature", value: signature.0, severity: signature.1),
    ]))

    sections.append(DoctorReport.Section(title: "Updates", rows: [
        DoctorReport.Row(key: "Mode", value: "Manual only (Check for Updates… in App menu)", severity: "info"),
    ]))

    sections.append(DoctorReport.Section(title: "Versions", rows: [
        DoctorReport.Row(key: "bento CLI", value: CLI_VERSION, severity: nil),
        DoctorReport.Row(key: "Bento.app", value: installedVersion, severity: installExists ? "ok" : "fail"),
    ]))

    sections.append(DoctorReport.Section(title: "Config", rows: [
        DoctorReport.Row(key: "Deck path", value: path.path, severity: nil),
        DoctorReport.Row(key: "Deck exists", value: FileManager.default.fileExists(atPath: path.path) ? "yes" : "no — created on first launch", severity: nil),
        DoctorReport.Row(key: "Tiles", value: tilesCount > 0 ? "\(tilesCount)" : "(no deck yet)", severity: nil),
        DoctorReport.Row(key: "Schema", value: schemaVersion.map { "v\($0)" } ?? "(unknown)", severity: nil),
    ]))

    return DoctorReport(sections: sections)
}

func printDoctorReport(_ r: DoctorReport) {
    let isTTY = isatty(STDOUT_FILENO) != 0
    let useColor = isTTY && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    func colorize(_ s: String, _ code: String) -> String {
        guard useColor else { return s }
        return "\u{1B}[\(code)m\(s)\u{1B}[0m"
    }
    func severityTag(_ sev: String?) -> String {
        guard let sev = sev else { return "" }
        switch sev {
        case "ok":   return "  " + colorize("[ok]",   "32")
        case "warn": return "  " + colorize("[warn]", "33")
        case "fail": return "  " + colorize("[fail]", "31")
        case "info": return "  " + colorize("[info]", "2")
        default:     return ""
        }
    }

    print("Bento doctor")
    for (i, section) in r.sections.enumerated() {
        if i > 0 { print("") }
        print(colorize(section.title, "1"))
        for row in section.rows {
            let key = row.key.padding(toLength: 14, withPad: " ", startingAt: 0)
            print("  \(key)  \(row.value)\(severityTag(row.severity))")
        }
    }
    print("")
    if r.hasFailures {
        print(colorize("✗ Issues found.", "31") + " See https://github.com/RyanAlberts/bento#troubleshooting")
    } else {
        print(colorize("✓ All checks passed.", "32"))
    }
}

// ---------- export / import ----------

func cmdExport() {
    let path = deckPath()
    if let data = try? Data(contentsOf: path) {
        FileHandle.standardOutput.write(data)
    } else {
        FileHandle.standardError.write(Data("No deck to export at \(path.path). Bento.app creates the deck on first launch.\n".utf8))
        exit(1)
    }
}

func cmdImport() {
    let path = deckPath()
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard !data.isEmpty else {
        FileHandle.standardError.write(Data("Stdin was empty — nothing to import. Pipe a deck.json into `bento import`. Docs: https://github.com/RyanAlberts/bento#sync\n".utf8))
        exit(2)
    }
    do {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: path, options: .atomic)
        print("Imported \(data.count) bytes into \(path.path)")
    } catch {
        FileHandle.standardError.write(Data("Import failed: \(error.localizedDescription). Could not write to \(path.path). Check filesystem permissions or run `bento doctor`.\n".utf8))
        exit(1)
    }
}
