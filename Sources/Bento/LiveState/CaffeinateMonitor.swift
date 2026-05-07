import Foundation
import SwiftUI

@MainActor
final class CaffeinateMonitor: ObservableObject {
    struct Assertion: Equatable {
        let kind: LiveKind
        let startedAt: Date
        let durationSeconds: Double
        var elapsedFraction: Double {
            min(1.0, max(0.0, Date().timeIntervalSince(startedAt) / durationSeconds))
        }
    }

    @Published private(set) var assertions: [LiveKind: Assertion] = [:]
    private var timer: Timer?

    static let shared = CaffeinateMonitor()

    init() {
        // Tick every second so live ring tiles update smoothly.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func start(_ kind: LiveKind, durationSeconds: Double) {
        assertions[kind] = Assertion(kind: kind, startedAt: Date(), durationSeconds: durationSeconds)
    }

    func clear(_ kind: LiveKind) {
        assertions.removeValue(forKey: kind)
    }

    func assertion(for kind: LiveKind) -> Assertion? {
        assertions[kind]
    }

    private func tick() {
        for (kind, assertion) in assertions where assertion.elapsedFraction >= 1.0 {
            assertions.removeValue(forKey: kind)
        }
        // Trigger a SwiftUI refresh even if no assertion expired this tick.
        objectWillChange.send()
    }
}
