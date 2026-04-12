import SwiftUI

struct PulseView: View {
    let level: Double
    let barCount = 14

    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                PulseBar(
                    index: i,
                    level: level,
                    animate: animate
                )
            }
        }
        .frame(height: 36)
        .onAppear {
            animate = true
        }
    }
}

struct PulseBar: View {
    let index: Int
    let level: Double
    let animate: Bool

    @State private var phase: Double = 0

    var body: some View {
        let baseHeight = 4.0 + level * 28.0
        let variation = sin(phase + Double(index) * 0.5) * level * 12.0
        let height = max(4, baseHeight + variation)

        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.46, blue: 0.82),
                        Color(red: 0.26, green: 0.65, blue: 0.96)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: height)
            .onAppear {
                guard animate else { return }
                withAnimation(
                    .easeInOut(duration: 1.2 + Double(index) * 0.08)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.06)
                ) {
                    phase = .pi * 2
                }
            }
    }
}
