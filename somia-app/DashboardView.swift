//
//  DashboardView.swift
//  somia-app
//
//  Created by Nathéo Brault on 23/03/2026.
//

import SwiftUI
import HealthKit

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

    // MARK: - Metric Trends

    private var hrvTrend: (text: String, color: Color) {
        guard let hrv = latestHRV, hrvAvg30 > 0 else {
            return ("Données insuffisantes", Color.somiaBodyText)
        }
        let pct = ((hrv - hrvAvg30) / hrvAvg30) * 100
        if pct >= 10  { return ("Progression forte", .somiaGreenStrong) }
        if pct >= 3   { return ("Progression",        .somiaGreenSoft) }
        if pct >= -3  { return ("Stable",              Color.somiaBodyText) }
        if pct >= -10 { return ("Dérive légère",       Color.somiaWarn) }
        return ("Baisse forte", .red)
    }

    private var sleepTrend: (text: String, color: Color) {
        let h = lastNightSleep
        guard h > 0 else { return ("Données insuffisantes", Color.somiaBodyText) }
        if h >= 8 { return ("Progression forte", .somiaGreenStrong) }
        if h >= 7 { return ("Progression",        .somiaGreenSoft) }
        if h >= 6 { return ("Stable",              Color.somiaBodyText) }
        if h >= 5 { return ("Dérive légère",       Color.somiaWarn) }
        return ("Baisse forte", .red)
    }

    // Mock values for metrics not yet tracked by HealthKitManager (SpO2, resting HR).
    // These will be replaced once the corresponding HealthKit types are added.
    private var spo2Display: (value: String, trend: String, trendColor: Color) {
        ("98 %", "Stable", Color.somiaBodyText)
    }
    private var restingHRDisplay: (value: String, trend: String, trendColor: Color) {
        ("52 bpm", "Progression", .somiaGreenSoft)
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
                        physiologicalCard
                        metricsSection
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

                Text("Bonjour, Alex")
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

    // MARK: - Physiological State Card

    private var physiologicalCard: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Section label
            Text("ÉTAT PHYSIOLOGIQUE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(1.5)

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
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.somiaCard)
                // Subtle tinted glow based on score
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardGlowColor.opacity(0.07))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
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

    // MARK: - "Ce matin" Metrics Grid

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CE MATIN")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(1.5)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                metricCard(
                    label: "HRV nuit",
                    value: latestHRV.map { String(format: "%.0f ms", $0) } ?? "-- ms",
                    trend: hrvTrend.text,
                    trendColor: hrvTrend.color
                )
                metricCard(
                    label: "Sommeil",
                    value: lastNightSleep > 0 ? String(format: "%.1f h", lastNightSleep) : "-- h",
                    trend: sleepTrend.text,
                    trendColor: sleepTrend.color
                )
                metricCard(
                    label: "SpO2",
                    value: spo2Display.value,
                    trend: spo2Display.trend,
                    trendColor: spo2Display.trendColor
                )
                metricCard(
                    label: "Tendance FC",
                    value: restingHRDisplay.value,
                    trend: restingHRDisplay.trend,
                    trendColor: restingHRDisplay.trendColor
                )
            }
        }
    }

    private func metricCard(
        label: String,
        value: String,
        trend: String,
        trendColor: Color
    ) -> some View {
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
