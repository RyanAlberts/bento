import Foundation
import AppKit

struct OpenURLAction: Action {
    static let kind = "url"
    let rawURL: String

    func execute() async throws {
        guard let url = URL(string: rawURL) else {
            throw ActionError.invalidURL(rawURL)
        }
        _ = await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }
}
