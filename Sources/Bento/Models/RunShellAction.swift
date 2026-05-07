import Foundation

struct RunShellAction: Action {
    static let kind = "shell"
    let command: String

    func execute() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")

            // -lc (login + run command), NOT -ilc.
            // We deliberately drop the -i (interactive) flag because interactive
            // shells source ~/.zshrc, which on most setups touches files in
            // ~/Documents and ~/Desktop (history files, fzf caches, nvm shims,
            // etc.) — and that's what triggers macOS's "Bento wants to access
            // your Desktop folder" prompt every launch. Login still sources
            // ~/.zprofile, where most users put their PATH additions, so
            // Homebrew + system tools still resolve.
            process.arguments = ["-lc", command]

            // Force CWD to $HOME so the shell never starts in a TCC-protected
            // folder (Desktop / Documents / Downloads). Inheriting Bento's CWD
            // is what made us look like we were "snooping" in Desktop on every
            // shell invocation.
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = Pipe()

            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    cont.resume()
                } else {
                    let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = String(data: data, encoding: .utf8) ?? ""
                    cont.resume(throwing: ActionError.shellNonZero(exitCode: p.terminationStatus, stderr: stderr))
                }
            }

            do {
                try process.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
