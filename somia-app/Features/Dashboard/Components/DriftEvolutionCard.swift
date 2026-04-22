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
        let isSufficient: Bool  // false = fewer than 5 HRV data points this week
        var date: Date {
            Calendar.current.date(byAdding: .weekOfYear, value: weekOffset - 12, to: Date()) ?? Date()
        }
    }

    let points: [WeeklyPoint]

    // MARK: Empty state

    private var isEmpty: Bool {
        points.filter { $0.isSufficient }.count < 4
    }

    private var isComingSoon: Bool {
        true
    }

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
        if isComingSoon {
            comingSoonStateView
        } else if isEmpty {
            emptyStateView
        } else {
            VStack(alignment: .leading, spacing: 14) {

                // Header — score + delta badge
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(currentScore >= 0 ? "+" : "")\(currentScore)")
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
                let sufficientPoints = points.filter { $0.isSufficient }
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
                    ForEach(sufficientPoints) { pt in
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
                    ForEach(sufficientPoints) { pt in
                        LineMark(
                            x: .value("Semaine", pt.weekOffset),
                            y: .value("Score",   pt.score)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(lineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }

                    // Latest point dot
                    if let last = sufficientPoints.last {
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(Color.somiaBodyText.opacity(0.25))
            Text("Pas encore assez de données")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.somiaBodyText.opacity(0.5))
            Text("Il faut au moins 4 semaines de données Apple Watch pour afficher la vue 3 mois.")
                .font(.system(size: 12))
                .foregroundStyle(Color.somiaBodyText.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .driftCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.somiaCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Coming Soon State

    private var comingSoonStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(Color.somiaBodyText.opacity(0.25))
            Text("Disponible bientôt !")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.somiaBodyText.opacity(0.5))
            Text("Cette vue sera disponible bientôt.")
                .font(.system(size: 12))
                .foregroundStyle(Color.somiaBodyText.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .driftCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.somiaCardBorder, lineWidth: 1)
        )
    }
}



// MARK: - Preview

#Preview {
    DriftEvolutionCard(points: [
        .init(weekOffset:  0, score: -62, isSufficient: true),
        .init(weekOffset:  1, score: -55, isSufficient: true),
        .init(weekOffset:  2, score: -48, isSufficient: true),
        .init(weekOffset:  3, score: -38, isSufficient: true),
        .init(weekOffset:  4, score: -22, isSufficient: true),
        .init(weekOffset:  5, score:  -8, isSufficient: true),
        .init(weekOffset:  6, score:   5, isSufficient: true),
        .init(weekOffset:  7, score:  14, isSufficient: true),
        .init(weekOffset:  8, score:  -3, isSufficient: true),
        .init(weekOffset:  9, score:  18, isSufficient: true),
        .init(weekOffset: 10, score:  28, isSufficient: true),
        .init(weekOffset: 11, score:  35, isSufficient: true),
        .init(weekOffset: 12, score: -23, isSufficient: true),
    ])
    .padding()
    .background(Color.somiaBackground)
}
