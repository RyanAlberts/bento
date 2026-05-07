import Foundation
import AppKit

struct LaunchAppAction: Action {
    static let kind = "app"
    let path: String

    func execute() async throws {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ActionError.appNotFound(path: path)
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        try await NSWorkspace.shared.openApplication(at: url, configuration: cfg)
    }
}
