import SwiftUI

struct BaselineScreen: View {
    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                BaselineChartView()
                    .frame(height: 190)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 16)

                Spacer()

                VStack(spacing: 16) {
                    Text("Votre baseline,\nrien que la vôtre")
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)

                    Text("Somia ne vous compare pas à une moyenne. Elle vous compare à vous-même, sur vos 60 derniers jours.")
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.somiaBodyText)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.55).delay(0.1), value: appeared)
                }
                .padding(.horizontal, 8)

                Spacer()

                OnboardingCTAButton(title: "Continuer", action: onContinue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.55).delay(0.2), value: appeared)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}

// MARK: - Chart

private struct BaselineChartView: View {
    // Points normalized [0, 1] where 1 = top of chart area
    private let baseline: [CGFloat] = [0.50, 0.52, 0.48, 0.51, 0.49, 0.50, 0.52, 0.49, 0.51, 0.50, 0.48, 0.52]
    private let drift:    [CGFloat] = [0.50, 0.52, 0.50, 0.55, 0.58, 0.63, 0.68, 0.73, 0.77, 0.81, 0.84, 0.86]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.somiaCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.somiaCardBorder, lineWidth: 1)
                )

            // Grid
            GeometryReader { geo in
                let inset: CGFloat = 20
                let chartW = geo.size.width  - inset * 2
                let chartH = geo.size.height - inset * 2 - 30 // leave room for legend

                // Horizontal grid lines
                ForEach(0..<3, id: \.self) { i in
                    let y = inset + chartH * CGFloat(i) / 2
                    Path { p in
                        p.move(to: CGPoint(x: inset, y: y))
                        p.addLine(to: CGPoint(x: inset + chartW, y: y))
                    }
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                }

                // Baseline fill area (subtle)
                buildFillPath(points: baseline, x: inset, y: inset, w: chartW, h: chartH)
                    .fill(
                        LinearGradient(
                            colors: [Color.somiaAccent.opacity(0.08), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Baseline dashed line
                buildPath(points: baseline, x: inset, y: inset, w: chartW, h: chartH)
                    .stroke(
                        Color.somiaAccent.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
                    )

                // Drift line
                buildPath(points: drift, x: inset, y: inset, w: chartW, h: chartH)
                    .stroke(
                        Color.somiaWarn,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
            }

            // Legend
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    legendItem(color: Color.somiaAccent.opacity(0.55), dashed: true, label: "Baseline")
                    legendItem(color: Color.somiaWarn, dashed: false, label: "Dérive")
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    private func buildPath(points: [CGFloat], x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        let step = w / CGFloat(points.count - 1)
        for (i, p) in points.enumerated() {
            let px = x + CGFloat(i) * step
            let py = y + (1 - p) * h
            if i == 0 {
                path.move(to: CGPoint(x: px, y: py))
            } else {
                let prevX = x + CGFloat(i - 1) * step
                let prevY = y + (1 - points[i - 1]) * h
                path.addCurve(
                    to: CGPoint(x: px, y: py),
                    control1: CGPoint(x: prevX + step / 2, y: prevY),
                    control2: CGPoint(x: px - step / 2, y: py)
                )
            }
        }
        return path
    }

    private func buildFillPath(points: [CGFloat], x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> Path {
        var path = buildPath(points: points, x: x, y: y, w: w, h: h)
        path.addLine(to: CGPoint(x: x + w, y: y + h))
        path.addLine(to: CGPoint(x: x, y: y + h))
        path.closeSubpath()
        return path
    }

    private func legendItem(color: Color, dashed: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 14, height: 2)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.somiaBodyText)
        }
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        BaselineScreen(onContinue: {})
    }
}
