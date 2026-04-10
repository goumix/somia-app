//
//  DriftYearCard.swift
//  somia-app
//

import SwiftUI

// MARK: - DriftYearCard

/// Card 3 — "1 an" : liste des 12 derniers mois avec barres divergentes.
struct DriftYearCard: View {

    // MARK: Data

    struct MonthlyPoint: Identifiable {
        let id = UUID()
        let monthLabel: String   // 3-char French abbreviation
        let score: Int
    }

    private let months: [MonthlyPoint] = [
        .init(monthLabel: "Avr", score: -58),
        .init(monthLabel: "Mai", score: -44),
        .init(monthLabel: "Jun", score: -29),
        .init(monthLabel: "Jul", score:  -8),
        .init(monthLabel: "Aoû", score:  12),
        .init(monthLabel: "Sep", score:  33),
        .init(monthLabel: "Oct", score:  41),
        .init(monthLabel: "Nov", score:  18),
        .init(monthLabel: "Déc", score:  -5),
        .init(monthLabel: "Jan", score: -18),
        .init(monthLabel: "Fév", score:   7),
        .init(monthLabel: "Mar", score: -23),
    ]

    // MARK: Counts

    private var progressionCount: Int { months.filter { $0.score >  20 }.count }
    private var stableCount:      Int { months.filter { $0.score >= -15 && $0.score <= 20 }.count }
    private var driftCount:       Int { months.filter { $0.score <  -15 }.count }

    // MARK: Helpers

    private func barColor(for score: Int) -> Color {
        score > 20 ? .somiaGreenStrong : (score < -15 ? .somiaDrift : Color.somiaBodyText.opacity(0.6))
    }

    private func barFraction(for score: Int) -> Double {
        // Normalise |score| to [0, 1] relative to 100
        min(1.0, Double(abs(score)) / 100.0)
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Rows
            ForEach(months) { month in
                monthRow(month)
                if month.id != months.last?.id {
                    Divider()
                        .background(Color.somiaCardBorder)
                }
            }

            // Footer summary
            Rectangle()
                .fill(Color.somiaCardBorder)
                .frame(height: 1)
                .padding(.top, 8)

            HStack(spacing: 0) {
                footerStat(count: progressionCount, label: "en progression", color: .somiaGreenStrong)
                footerDot()
                footerStat(count: stableCount, label: "stables", color: Color.somiaBodyText)
                footerDot()
                footerStat(count: driftCount, label: "en dérive", color: .somiaDrift)
            }
            .padding(.top, 10)
        }
        .driftCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.somiaCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Row

    private func monthRow(_ month: MonthlyPoint) -> some View {
        let color = barColor(for: month.score)
        let fraction = barFraction(for: month.score)
        let isPositive = month.score >= 0

        return HStack(spacing: 10) {
            // Colored dot
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            // Month label
            Text(month.monthLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.somiaBodyText)
                .frame(width: 28, alignment: .leading)

            // Diverging bar
            GeometryReader { geo in
                let midX = geo.size.width / 2
                let barWidth = geo.size.width / 2 * fraction

                ZStack(alignment: .center) {
                    // Center reference line
                    Rectangle()
                        .fill(Color.somiaCardBorder)
                        .frame(width: 1, height: 6)
                        .position(x: midX, y: geo.size.height / 2)

                    // Bar
                    Rectangle()
                        .fill(color)
                        .frame(width: max(2, barWidth), height: 6)
                        .clipShape(Capsule())
                        .position(
                            x: isPositive ? midX + barWidth / 2 : midX - barWidth / 2,
                            y: geo.size.height / 2
                        )
                }
            }
            .frame(height: 16)

            // Score value
            Text(month.score >= 0 ? "+\(month.score)" : "\(month.score)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }

    // MARK: - Footer helpers

    private func footerStat(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(Color.somiaBodyText)
        }
        .font(.caption2)
    }

    private func footerDot() -> some View {
        Text("·")
            .font(.caption2)
            .foregroundStyle(Color.somiaBodyText)
            .padding(.horizontal, 4)
    }
}

// MARK: - Preview

#Preview {
    DriftYearCard()
        .padding()
        .background(Color.somiaBackground)
}
