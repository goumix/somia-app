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
        let isSufficient: Bool   // false = fewer than 5 data points this month
    }

    let months: [MonthlyPoint]

    // MARK: Counts

    private var progressionCount: Int { months.filter { $0.score >  20 }.count }
    private var stableCount:      Int { months.filter { $0.score >= -15 && $0.score <= 20 }.count }
    private var driftCount:       Int { months.filter { $0.score <  -15 }.count }

    private var isEmpty: Bool {
        months.filter { $0.isSufficient }.count < 4
    }

    private var isComingSoon: Bool {
        true
    }

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
        if isComingSoon {
            comingSoonStateView
        } else if isEmpty {
            emptyStateView
        } else {
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
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28))
                .foregroundStyle(Color.somiaBodyText.opacity(0.25))
            Text("Pas encore assez de données")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.somiaBodyText.opacity(0.5))
            Text("Il faut au moins 4 mois de données Apple Watch pour afficher la vue annuelle.")
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
            Image(systemName: "chart.bar.fill")
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

            if month.isSufficient {
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
            } else {
                Text("données insuffisantes")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.somiaBodyText.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
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
    DriftYearCard(months: [
        .init(monthLabel: "Avr", score: -58, isSufficient: true),
        .init(monthLabel: "Mai", score: -44, isSufficient: true),
        .init(monthLabel: "Jun", score: -29, isSufficient: true),
        .init(monthLabel: "Jul", score:  -8, isSufficient: true),
        .init(monthLabel: "Aoû", score:  12, isSufficient: true),
        .init(monthLabel: "Sep", score:  33, isSufficient: true),
        .init(monthLabel: "Oct", score:  41, isSufficient: true),
        .init(monthLabel: "Nov", score:  18, isSufficient: true),
        .init(monthLabel: "Déc", score:  -5, isSufficient: true),
        .init(monthLabel: "Jan", score: -18, isSufficient: true),
        .init(monthLabel: "Fév", score:   7, isSufficient: true),
        .init(monthLabel: "Mar", score: -23, isSufficient: true),
    ])
    .padding()
    .background(Color.somiaBackground)
}
