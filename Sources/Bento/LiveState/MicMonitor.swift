import Foundation
import SwiftUI

@MainActor
final class MicMonitor: ObservableObject {
    @Published private(set) var isMuted: Bool = false
    private var timer: Timer?

    static let shared = MicMonitor()

    init() {
        // Poll input volume via AppleScript every 2s. Cheaper than CoreAudio listeners for v1.
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    private func refresh() async {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "input volume of (get volume settings)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let level = Int(str) ?? 0
            let nowMuted = level == 0
            if nowMuted != isMuted {
                isMuted = nowMuted
            }
        } catch {
            // Silent — mic state polling failure shouldn't crash the app
        }
    }
}
