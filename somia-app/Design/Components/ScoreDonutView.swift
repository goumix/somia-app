import SwiftUI
import Charts

// MARK: - ScoreDonutData

struct ScoreDonutData {
    struct Segment: Identifiable {
        let id: String
        let points: Int
        let color: Color
    }
    let total: Int
    let label: String
    let segments: [Segment]
}

// MARK: - ScoreDonutView

struct ScoreDonutView: View {
    let data: ScoreDonutData?
    var size: CGFloat = 96

    private var displaySegments: [ScoreDonutData.Segment] {
        guard let d = data else {
            return [.init(id: "empty", points: 100, color: .white.opacity(0.07))]
        }
        var s = d.segments.filter { $0.points > 0 }
        let empty = 100 - d.total
        if empty > 0 { s.append(.init(id: "empty", points: empty, color: .white.opacity(0.07))) }
        return s
    }

    var body: some View {
        ZStack {
            Chart(displaySegments) { seg in
                SectorMark(
                    angle: .value("pts", seg.points),
                    innerRadius: .ratio(0.72),
                    angularInset: data != nil ? 2.5 : 0
                )
                .cornerRadius(4)
                .foregroundStyle(seg.color)
            }
            .frame(width: size, height: size)

            VStack(spacing: 2) {
                Text(data.map { "\($0.total)" } ?? "--")
                    .font(.system(size: size < 120 ? 15 : 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if size >= 120, let label = data?.label {
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
            ScoreDonutView(data: nil)
            ScoreDonutView(data: nil, size: 200)
        }
    }
}
