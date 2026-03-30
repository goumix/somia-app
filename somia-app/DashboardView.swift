//
//  DashboardView.swift
//  somia-app
//
//  Created by Nathéo Brault on 23/03/2026.
//

import SwiftUI
import HealthKit

// MARK: - RingMetricView

struct RingMetricView: View {
    let label: String
    let value: String
    let progress: Double
    /// Two colors defining the gradient arc: [startColor, endColor].
    let gradientColors: [Color]

    private let ringSize: CGFloat = 96
    private let lineWidth: CGFloat = 13

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
                    .frame(width: ringSize, height: ringSize)

                // Progress arc with gradient
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.7), value: progress)
                    .shadow(color: (gradientColors.last ?? .white).opacity(0.4), radius: 8)

                // Center value
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: ringSize - lineWidth * 2 - 8)
                    .multilineTextAlignment(.center)
            }
            // Subtle depth shadow on the whole ring
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576)) // #8E8E93
        }
    }
}

// MARK: - MetricCard

struct MetricCard: View {
    let label: String
    let value: String
    let trend: String
    let trendColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(0.6)

            Spacer().frame(height: 8)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            // Pill-shaped trend label
            Text(trend)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(trendColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(trendColor.opacity(0.13))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(16)
        .background(Color.somiaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.somiaCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - DashboardView

struct DashboardView: View {

    // MARK: - Dependencies

    #if targetEnvironment(simulator)
    @State private var hk: any HealthKitManaging = HealthKitManagerMock()
    #else
    @State private var hk: any HealthKitManaging = HealthKitManager.shared
    #endif

    private let msUnit = HKUnit.secondUnit(with: .milli)

    // MARK: - Computed: HRV

    /// Most recent HRV sample (samples are sorted descending by date).
    private var latestHRV: Double? {
        hk.hrvSamples.first.map { $0.quantity.doubleValue(for: msUnit) }
    }

    /// 30-day HRV mean used as baseline for scoring.
    private var hrvAvg30: Double {
        guard !hk.hrvSamples.isEmpty else { return 0 }
        let values = hk.hrvSamples.map { $0.quantity.doubleValue(for: msUnit) }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Computed: Sleep

    /// Total sleep duration for the most recent night (in hours).
    private var lastNightSleep: Double {
        let calendar = Calendar.current
        let actualSleepStates: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        var byNight: [Date: Double] = [:]
        for sample in hk.sleepSamples where actualSleepStates.contains(sample.value) {
            let night = calendar.startOfDay(for: sample.startDate)
            byNight[night, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
        }
        return byNight.sorted { $0.key > $1.key }.first?.value ?? 0
    }

    // MARK: - Computed: Composite Score

    /// Composite physiological drift score in [-100, +100].
    /// HRV contributes ±50 pts (based on deviation from 30-day mean).
    /// Sleep contributes ±50 pts (based on deviation from 7.5 h baseline).
    private var compositeScore: Int {
        var score: Double = 0

        if let hrv = latestHRV, hrvAvg30 > 0 {
            let ratio = (hrv - hrvAvg30) / hrvAvg30
            // Scale: a 25 % deviation equals ±50 pts
            score += min(50, max(-50, ratio * 200))
        }

        let sleep = lastNightSleep
        if sleep > 0 {
            // +50 at 11.5 h, -50 at 3.5 h, 0 at 7.5 h baseline
            score += min(50, max(-50, (sleep - 7.5) * 12.5))
        }

        return Int(min(100, max(-100, score)))
    }

    // MARK: - Score Presentation

    private var scoreInfo: (label: String, color: Color) {
        switch compositeScore {
        case 55...100:   return ("En progression forte",  .somiaGreenStrong)
        case 20...54:    return ("En progression",         .somiaGreenSoft)
        case -15...19:   return ("Stable",                 Color.somiaBodyText)
        case -45 ... -16: return ("En dérive légère",    Color.somiaWarn)
        case -70 ... -46: return ("En dérive modérée",   Color(red: 1.0, green: 0.40, blue: 0.10))
        default:          return ("En dérive sévère",     .red)
        }
    }

    private var scoreArrows: String {
        switch compositeScore {
        case 55...100:   return "↑↑"
        case 20...54:    return "↑"
        case -15...19:   return "→"
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

    /// Subtle tinted overlay on the main card background.
    private var cardGlowColor: Color {
        if compositeScore > 20  { return .somiaGreenStrong }
        if compositeScore < -20 { return Color(red: 0.50, green: 0.25, blue: 0.95) }
        return Color.somiaBodyText
    }

    // MARK: - Ring Progress

    private var hrvProgress: Double {
        guard let hrv = latestHRV, hrvAvg30 > 0 else { return 0 }
        return min(1.0, max(0.0, hrv / hrvAvg30))
    }

    private var sleepProgress: Double {
        guard lastNightSleep > 0 else { return 0 }
        return min(1.0, max(0.0, lastNightSleep / 8.0))
    }

    // MARK: - Metric Display (mock for untracked metrics)

    private var spo2Display: (value: String, trend: String, trendColor: Color) {
        ("98 %", "Stable", Color.somiaBodyText)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: Date()).uppercased()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            if hk.isLoading {
                ProgressView()
                    .tint(Color.somiaAccent)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection
                        physiologicalCard(title: "ÉTAT PHYSIOLOGIQUE (1 mois)")
                        todaySection
                        physiologicalCard(title: "ÉTAT PHYSIOLOGIQUE (3 mois)")
                        physiologicalCard(title: "ÉTAT PHYSIOLOGIQUE (1 an)")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await hk.requestAuthorization()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                // Date in small caps style
                Text(formattedDate)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.somiaBodyText)
                    .tracking(1.2)

                Text("Bonjour Alex")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            Spacer()

            // Avatar with initial
            ZStack {
                Circle()
                    .fill(Color.somiaAccent.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text("A")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.somiaAccent)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Physiological Card

    private func physiologicalCard(title: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            // Section label
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(1.5)
            
            VStack(alignment: .leading, spacing: 16) {
                // Score + arrows + label
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    (Text(compositeScore >= 0 ? "+" : "") + Text("\(compositeScore)"))
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
                
                // Non-interactive progress bar with axis labels
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
                
                // Navigation CTA — pushes HealthDebugView onto the NavigationStack
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
            .padding(16)
            .background(Color.somiaCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardGlowColor.opacity(0.22), lineWidth: 1)
            )
        }
    }

    /// Horizontal gradient bar with a white thumb positioned at the current score.
    private var scoreProgressBar: some View {
        GeometryReader { proxy in
            let thumbSize: CGFloat = 18
            let usableWidth = proxy.size.width - thumbSize
            let position = CGFloat(compositeScore + 100) / 200.0 * usableWidth

            ZStack(alignment: .leading) {
                // Gradient track: red (drift) → neutral → green (progression)
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

                // Thumb indicator
                Circle()
                    .fill(.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: scoreInfo.color.opacity(0.55), radius: 5)
                    .offset(x: position)
            }
        }
        .frame(height: 18)
    }

    // MARK: - "Aujourd'hui" Ring Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AUJOURD'HUI")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(1.5)

            HStack(spacing: 0) {
                // HRV — orange gradient (#FFD60A → #FF9F0A)
                RingMetricView(
                    label: "Effort",
                    value: latestHRV.map { String(format: "%.0f ms", $0) } ?? "-- ms",
                    progress: hrvProgress,
                    gradientColors: [
                        Color(red: 1.0,   green: 0.839, blue: 0.039),
                        Color(red: 1.0,   green: 0.624, blue: 0.039)
                    ]
                )
                .frame(maxWidth: .infinity)

                // Sommeil — lavande gradient (#A78BFA → #818CF8)
                RingMetricView(
                    label: "Récupération",
                    value: lastNightSleep > 0 ? String(format: "%.1f h", lastNightSleep) : "-- h",
                    progress: sleepProgress,
                    gradientColors: [
                        Color(red: 0.655, green: 0.545, blue: 0.980),
                        Color(red: 0.506, green: 0.549, blue: 0.973)
                    ]
                )
                .frame(maxWidth: .infinity)

                // SpO2 — vert gradient (#86EFAC → #22C55E)
                RingMetricView(
                    label: "Sommeil",
                    value: spo2Display.value,
                    progress: 0.98,
                    gradientColors: [
                        Color(red: 0.525, green: 0.937, blue: 0.675),
                        Color(red: 0.133, green: 0.773, blue: 0.369)
                    ]
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)
            .background(Color.somiaCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.somiaCardBorder, lineWidth: 1)
            )
        }
    }
}


// MARK: - Theme Colors (Dashboard-specific)

private extension Color {
    /// Vivid green — progression forte (#4ADE80)
    static let somiaGreenStrong = Color(red: 0.290, green: 0.871, blue: 0.502)
    /// Soft green — progression (#86EFAC)
    static let somiaGreenSoft   = Color(red: 0.525, green: 0.937, blue: 0.675)
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
    }
}
