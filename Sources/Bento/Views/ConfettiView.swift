import SwiftUI

/// Burst-style confetti — pieces explode out from the center of the panel,
/// then drift downward as gravity takes over and fade as they go.
struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.45)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(piece.position)
                        .opacity(piece.opacity)
                }
            }
            .allowsHitTesting(false)
            .onReceive(NotificationCenter.default.publisher(for: .bentoFireConfetti)) { _ in
                fire(in: geo.size)
            }
        }
    }

    private func fire(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let colors: [Color] = [.red, .orange, .yellow, .green, .mint, .teal, .blue, .indigo, .purple, .pink]

        // Spawn ~80 pieces at the center, all stationary at first.
        var fresh: [ConfettiPiece] = []
        for _ in 0..<80 {
            // Direction & speed: each piece gets a random angle around the full
            // circle, plus a random burst distance. We bias slightly upward by
            // shifting a chunk of the pieces toward the top half.
            let angle = Double.random(in: 0..<(2 * .pi))
            let burstDistance = CGFloat.random(in: 60...190)
            let dx = cos(angle) * burstDistance
            // Bias the burst toward the upper hemisphere so it looks like an
            // explosion rather than rain. -0.6 weights the y component upward
            // (negative y = up in screen coords) before gravity takes over.
            let dy = sin(angle) * burstDistance - 35

            fresh.append(
                ConfettiPiece(
                    startPosition: center,
                    burstTarget: CGPoint(x: center.x + dx, y: center.y + dy),
                    color: colors.randomElement()!,
                    size: CGFloat.random(in: 6...12),
                    rotation: Double.random(in: 0...360),
                    finalRotation: Double.random(in: 360...1080) * (Bool.random() ? 1 : -1),
                    opacity: 1,
                    position: center
                )
            )
        }
        pieces = fresh

        // Phase 1 — burst outward (~0.45s, eased out so it feels like an explosion).
        withAnimation(.easeOut(duration: 0.45)) {
            for i in pieces.indices {
                pieces[i].position = pieces[i].burstTarget
                pieces[i].rotation = pieces[i].finalRotation * 0.4
            }
        }

        // Phase 2 — gravity pulls everything down, with horizontal drift.
        // Starts after the burst so the two motions chain rather than blend.
        Task {
            try? await Task.sleep(nanoseconds: 380_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 1.6)) {
                    for i in pieces.indices {
                        let drift = CGFloat.random(in: -25...25)
                        pieces[i].position.x = pieces[i].burstTarget.x + drift
                        pieces[i].position.y = size.height + 40
                        pieces[i].rotation = pieces[i].finalRotation
                        pieces[i].opacity = 0
                    }
                }
            }

            // Cleanup once everything has fallen + faded.
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            await MainActor.run { pieces = [] }
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let startPosition: CGPoint
    let burstTarget: CGPoint
    let color: Color
    let size: CGFloat
    var rotation: Double
    let finalRotation: Double
    var opacity: Double
    var position: CGPoint
}
