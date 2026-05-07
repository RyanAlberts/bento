import SwiftUI

struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var trigger: Int = 0

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                Rectangle()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 0.4)
                    .rotationEffect(.degrees(piece.rotation))
                    .position(piece.position)
                    .opacity(piece.opacity)
            }
        }
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: .bentoFireConfetti)) { _ in
            fire()
        }
    }

    private func fire() {
        let bounds = CGSize(width: 360, height: 220)
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        var fresh: [ConfettiPiece] = []
        for _ in 0..<60 {
            fresh.append(
                ConfettiPiece(
                    position: CGPoint(x: CGFloat.random(in: 20...(bounds.width - 20)), y: -10),
                    color: colors.randomElement()!,
                    size: CGFloat.random(in: 6...11),
                    rotation: Double.random(in: 0...360),
                    opacity: 1
                )
            )
        }
        pieces = fresh
        trigger += 1

        // Animate fall + fade
        withAnimation(.easeOut(duration: 1.4)) {
            for i in pieces.indices {
                pieces[i].position.y = bounds.height + 40
                pieces[i].position.x += CGFloat.random(in: -50...50)
                pieces[i].rotation += Double.random(in: 180...720)
                pieces[i].opacity = 0
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { pieces = [] }
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var size: CGFloat
    var rotation: Double
    var opacity: Double
}
