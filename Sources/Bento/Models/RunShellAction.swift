import Foundation

struct RunShellAction: Action {
    static let kind = "shell"
    let command: String

    func execute() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // -i interactive + -l login → sources both .zprofile and .zshrc so Homebrew/nvm/pyenv PATH applies
            process.arguments = ["-ilc", command]

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
