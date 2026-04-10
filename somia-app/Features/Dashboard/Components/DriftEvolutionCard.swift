//
//  DriftEvolutionCard.swift
//  somia-app
//

import SwiftUI
import Charts

// MARK: - DriftEvolutionCard

/// Card 2 — "3 mois" : sparkline d'évolution hebdomadaire du score composite.
struct DriftEvolutionCard: View {

    // MARK: Data

    struct WeeklyPoint: Identifiable {
        let id = UUID()
        let weekOffset: Int   // 0 = il y a ~13 semaines, 12 = cette semaine
        let score: Int
        var date: Date {
            Calendar.current.date(byAdding: .weekOfYear, value: weekOffset - 12, to: Date()) ?? Date()
        }
    }

    private let points: [WeeklyPoint] = [
        .init(weekOffset:  0, score: -62),
        .init(weekOffset:  1, score: -55),
        .init(weekOffset:  2, score: -48),
        .init(weekOffset:  3, score: -38),
        .init(weekOffset:  4, score: -22),
        .init(weekOffset:  5, score:  -8),
        .init(weekOffset:  6, score:   5),
        .init(weekOffset:  7, score:  14),
        .init(weekOffset:  8, score:  -3),
        .init(weekOffset:  9, score:  18),
        .init(weekOffset: 10, score:  28),
        .init(weekOffset: 11, score:  35),
        .init(weekOffset: 12, score: -23),
    ]

    // MARK: Derived

    private var currentScore: Int { points.last?.score ?? 0 }
    private var earliestScore: Int { points.first?.score ?? 0 }
    private var delta: Int { currentScore - earliestScore }

    private var lineColor: Color {
        currentScore >= 0 ? .somiaGreenStrong : .somiaDrift
    }

    private var deltaColor: Color {
        delta > 0 ? .somiaGreenStrong : (delta < 0 ? .somiaDrift : Color.somiaBodyText)
    }

    private var deltaLabel: String {
        delta > 0 ? "+\(delta) pts" : "\(delta) pts"
    }

    // MARK: Month axis labels (3 labels across 13 weeks)

    private var axisMonths: [String] {
        let locale = Locale(identifier: "fr_FR")
        let cal    = Calendar.current
        let today  = Date()
        var result: [String] = []
        for offset in [0, 6, 12] {
            guard let d = cal.date(byAdding: .weekOfYear, value: -(12 - offset), to: today) else { continue }
            let fmt = DateFormatter()
            fmt.locale = locale
            fmt.dateFormat = "MMM"
            result.append(fmt.string(from: d).capitalized)
        }
        return result
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header — score + delta badge
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                (Text(currentScore >= 0 ? "+" : "") + Text("\(currentScore)"))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(lineColor)

                Spacer()

                // Delta badge
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(deltaLabel + " vs 3 mois")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(deltaColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(deltaColor.opacity(0.13))
                .clipShape(Capsule())
            }

            // Sparkline chart
            Chart {
                // Zero reference line
                RuleMark(y: .value("Zéro", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.somiaBodyText.opacity(0.4))

                // ±50 gridlines
                ForEach([-50, 50], id: \.self) { val in
                    RuleMark(y: .value("Ref", val))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        .foregroundStyle(Color.somiaBodyText.opacity(0.18))
                }

                // Area fill
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("Semaine", pt.weekOffset),
                        y: .value("Score",   pt.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.25), lineColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Line
                ForEach(points) { pt in
                    LineMark(
                        x: .value("Semaine", pt.weekOffset),
                        y: .value("Score",   pt.score)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }

                // Latest point dot
                if let last = points.last {
                    PointMark(
                        x: .value("Semaine", last.weekOffset),
                        y: .value("Score",   last.score)
                    )
                    .symbolSize(36)
                    .foregroundStyle(lineColor)
                }
            }
            .chartYScale(domain: -100...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: [-50, 0, 50]) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.clear) // handled by RuleMarks above
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(v >= 0 ? "+\(v)" : "\(v)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.somiaBodyText.opacity(0.5))
                        }
                    }
                }
            }
            .frame(height: 110)

            // X-axis month labels
            HStack {
                ForEach(axisMonths.indices, id: \.self) { i in
                    Text(axisMonths[i])
                        .font(.caption2)
                        .foregroundStyle(Color.somiaBodyText)
                    if i < axisMonths.count - 1 { Spacer() }
                }
            }
        }
        .driftCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.somiaCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    DriftEvolutionCard()
        .padding()
        .background(Color.somiaBackground)
}
