//
//  DriftScoreCard.swift
//  somia-app
//

import SwiftUI

// MARK: - DriftScoreCard

/// Card 1 — "1 mois" : score composite instantané, barre dégradée, insight contextuel.
struct DriftScoreCard: View {

    let compositeScore: Int

    // MARK: Score presentation

    private var scoreInfo: (label: String, color: Color) {
        switch compositeScore {
        case 55...100:    return ("En progression forte", .somiaGreenStrong)
        case 20...54:     return ("En progression",       .somiaGreenSoft)
        case -15...19:    return ("Stable",               Color.somiaBodyText)
        case -45 ... -16: return ("En dérive légère",     Color.somiaWarn)
        case -70 ... -46: return ("En dérive modérée",    Color(red: 1.0, green: 0.40, blue: 0.10))
        default:          return ("En dérive sévère",     .red)
        }
    }

    private var scoreArrows: String {
        switch compositeScore {
        case 55...100:    return "↑↑"
        case 20...54:     return "↑"
        case -15...19:    return "→"
        case -45 ... -16: return "↓"
        default:          return "↓↓"
        }
    }

    private var insightText: String {
        switch compositeScore {
        case 55...100:
            return "Bonne dynamique. Tes signaux progressent. Assure-toi que cette amélioration est durable sur 2 semaines avant de changer tes habitudes."
        case 20...54:
            return "Tu es sur une belle lancée. Continue à observer tes signaux sans forcer — la régularité prime sur l'intensité."
        case -15...19:
            return "Tes signaux sont stables. Maintiens tes habitudes actuelles et surveille les variations dans les prochains jours."
        case -45 ... -16:
            return "Une légère dérive est détectée. Priorise le sommeil et réduis les facteurs de stress pour les 48 prochaines heures."
        case -70 ... -46:
            return "Dérive modérée en cours. Tes signaux physiologiques appellent à la prudence. Récupération active recommandée."
        default:
            return "Dérive sévère détectée. Ton corps envoie des signaux d'alerte. Repos prioritaire et consultation possible."
        }
    }

    private var cardGlowColor: Color {
        if compositeScore > 20  { return .somiaGreenStrong }
        if compositeScore < -20 { return Color(red: 0.50, green: 0.25, blue: 0.95) }
        return Color.somiaBodyText
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Score + arrows + label
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(compositeScore >= 0 ? "+" : "")\(compositeScore)")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreInfo.color)

                Text(scoreArrows)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(scoreInfo.color)

                Spacer()

                Text(scoreInfo.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreInfo.color)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140, alignment: .trailing)
            }

            // Gradient progress bar
            VStack(alignment: .leading, spacing: 6) {
                scoreProgressBar
                HStack {
                    Text("−100 dérive")
                        .font(.caption2)
                        .foregroundStyle(Color.somiaBodyText)
                    Spacer()
                    Text("+100 progression")
                        .font(.caption2)
                        .foregroundStyle(Color.somiaBodyText)
                }
            }

            Rectangle()
                .fill(Color.somiaCardBorder)
                .frame(height: 1)

            // Contextual insight
            Text(insightText)
                .font(.subheadline)
                .foregroundStyle(Color.somiaBodyText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            // CTA
            NavigationLink(destination: HealthDebugView()) {
                HStack(spacing: 5) {
                    Text("Voir la tendance")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline)
                .foregroundStyle(Color.somiaAccent)
            }
        }
        .driftCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardGlowColor.opacity(0.22), lineWidth: 1)
        )
    }

    /// Horizontal gradient bar with a white thumb positioned at the current score.
    private var scoreProgressBar: some View {
        GeometryReader { proxy in
            let thumbSize: CGFloat = 18
            let usableWidth = proxy.size.width - thumbSize
            let position = CGFloat(compositeScore + 100) / 200.0 * usableWidth

            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [
                        .red,
                        Color.somiaWarn,
                        Color(red: 0.35, green: 0.35, blue: 0.40),
                        .somiaGreenSoft,
                        .somiaGreenStrong
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 8)
                .clipShape(Capsule())

                Circle()
                    .fill(.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: scoreInfo.color.opacity(0.55), radius: 5)
                    .offset(x: position)
            }
        }
        .frame(height: 18)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DriftScoreCard(compositeScore: -23)
            .padding()
            .background(Color.somiaBackground)
    }
}
