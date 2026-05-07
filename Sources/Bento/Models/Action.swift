import Foundation
import AppKit

protocol Action {
    static var kind: String { get }
    func execute() async throws
}

enum ActionError: Error {
    case shellNonZero(exitCode: Int32, stderr: String)
    case appNotFound(path: String)
    case invalidURL(String)
}

struct AnyAction: Codable, Hashable {
    var kind: String
    var payload: String

    init(kind: String, payload: String) {
        self.kind = kind
        self.payload = payload
    }

    func execute() async throws {
        switch kind {
        case LaunchAppAction.kind:
            try await LaunchAppAction(path: payload).execute()
        case OpenURLAction.kind:
            try await OpenURLAction(rawURL: payload).execute()
        case RunShellAction.kind:
            try await RunShellAction(command: payload).execute()
        default:
            throw ActionError.shellNonZero(exitCode: -1, stderr: "Unknown action kind: \(kind)")
        }
    }

    static func launchApp(_ path: String) -> AnyAction { .init(kind: LaunchAppAction.kind, payload: path) }
    static func openURL(_ url: String) -> AnyAction   { .init(kind: OpenURLAction.kind, payload: url) }
    static func shell(_ cmd: String) -> AnyAction     { .init(kind: RunShellAction.kind, payload: cmd) }
}
