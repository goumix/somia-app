import SwiftUI

struct ScoreRingView: View {
    let score: Double?          // 0–100, nil = état vide "--"
    var label: String = ""
    var size: CGFloat = 96
    var gradientColors: [Color]? = nil  // nil → scoreColor auto-calculée

    private var lineWidth: CGFloat { size * 0.135 }
    private var progress: Double { (score ?? 0) / 100.0 }

    private var resolvedColors: [Color] {
        guard let s = score else { return [Color.somiaBodyText] }
        let c = gradientColors ?? [Color.scoreColor(for: s)]
        return c
    }

    var body: some View {
        VStack(spacing: size < 120 ? 10 : 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
                    .frame(width: size, height: size)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(
                        LinearGradient(colors: resolvedColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.7), value: score)
                    .shadow(color: (resolvedColors.last ?? .white).opacity(0.4), radius: size < 120 ? 8 : 12)
                Text(score.map { "\(Int($0))" } ?? "--")
                    .font(.system(size: size < 120 ? 15 : 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: size - lineWidth * 2 - 8)
                    .multilineTextAlignment(.center)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)

            if !label.isEmpty {
                Text(label)
                    .font(.somiaCaption)
                    .foregroundStyle(Color.somiaBodyText)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        VStack(spacing: SomiaSpacing.xl) {
            HStack(spacing: SomiaSpacing.xl) {
                ScoreRingView(score: 82, label: "Effort")
                ScoreRingView(score: 45, label: "Récupération")
                ScoreRingView(score: nil, label: "Score")
            }
            ScoreRingView(score: 73, label: "Récupération", size: 200)
        }
    }
}
