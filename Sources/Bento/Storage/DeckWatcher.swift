import Foundation
import CoreServices

@MainActor
final class DeckWatcher {
    private var stream: FSEventStreamRef?
    private let url: URL
    private let onChange: () -> Void
    private var lastFiredAt: Date = .distantPast
    private let debounce: TimeInterval = 0.3

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        stop()
        let path = url.deletingLastPathComponent().path as NSString
        let pathsToWatch: CFArray = [path] as CFArray

        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)

        let callback: FSEventStreamCallback = { _, clientInfo, numEvents, _, _, _ in
            guard let clientInfo else { return }
            let watcher = Unmanaged<DeckWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
            Task { @MainActor in
                watcher.handleEvent(numEvents: Int(numEvents))
            }
        }

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )
        if let stream {
            FSEventStreamSetDispatchQueue(stream, .main)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func handleEvent(numEvents: Int) {
        let now = Date()
        guard now.timeIntervalSince(lastFiredAt) > debounce else { return }
        lastFiredAt = now
        onChange()
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
