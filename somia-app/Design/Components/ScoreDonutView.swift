import SwiftUI
import Charts

struct ScoreDonutView: View {
    let result: SleepScoreCalculator.Result?
    var size: CGFloat = 96

    private struct Segment: Identifiable {
        let id: String; let points: Int; let color: Color
    }

    private var segments: [Segment] {
        guard let r = result else {
            return [.init(id: "empty", points: 100, color: .white.opacity(0.07))]
        }
        var s: [Segment] = []
        if r.durationPoints     > 0 { s.append(.init(id: "dur",   points: r.durationPoints,     color: .somiaAccent)) }
        if r.bedtimePoints      > 0 { s.append(.init(id: "bed",   points: r.bedtimePoints,      color: .somiaWarn)) }
        if r.interruptionPoints > 0 { s.append(.init(id: "inter", points: r.interruptionPoints, color: .somiaGreenSoft)) }
        let empty = 100 - r.total
        if empty > 0 { s.append(.init(id: "empty", points: empty, color: .white.opacity(0.07))) }
        return s
    }

    var body: some View {
        ZStack {
            Chart(segments) { seg in
                SectorMark(
                    angle: .value("pts", seg.points),
                    innerRadius: .ratio(0.72),
                    angularInset: result != nil ? 2.5 : 0
                )
                .foregroundStyle(seg.color)
            }
            .frame(width: size, height: size)

            VStack(spacing: 2) {
                Text(result.map { "\($0.total)" } ?? "--")
                    .font(.system(size: size < 120 ? 15 : 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if size >= 120, let label = result?.label {
                    Text(label)
                        .font(.somiaCaption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        VStack(spacing: SomiaSpacing.xl) {
            ScoreDonutView(result: nil)
            ScoreDonutView(result: nil, size: 200)
        }
    }
}
