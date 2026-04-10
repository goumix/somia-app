//
//  DashboardView.swift
//  somia-app
//
//  Created by Nathéo Brault on 23/03/2026.
//

import SwiftUI

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

    // MARK: - ViewModel

    #if targetEnvironment(simulator)
    @State private var vm = DashboardViewModel(healthKit: HealthKitManagerMock())
    #else
    @State private var vm = DashboardViewModel()
    #endif

    @State private var showSettings = false

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

            if vm.isLoading {
                ProgressView()
                    .tint(Color.somiaAccent)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection
                        todaySection
                        cardGroupLabel("ÉTAT PHYSIOLOGIQUE · 1 MOIS")
                        DriftScoreCard(compositeScore: vm.compositeScore)
                        cardGroupLabel("ÉVOLUTION · 3 MOIS")
                        DriftEvolutionCard()
                        cardGroupLabel("TRAJECTOIRE · 1 AN")
                        DriftYearCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await vm.requestAuthorization()
        }
        .sheet(isPresented: $showSettings) {
            #if targetEnvironment(simulator)
            SettingsView(mock: vm.healthKit as! HealthKitManagerMock)
            #else
            SettingsView()
            #endif
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

            // Avatar — tap opens Settings
            Button { showSettings = true } label: {
                ZStack {
                    Circle()
                        .fill(Color.somiaAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text("A")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.somiaAccent)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Card Group Label

    private func cardGroupLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.somiaBodyText)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    value: vm.latestHRV.map { String(format: "%.0f ms", $0) } ?? "-- ms",
                    progress: vm.hrvProgress,
                    gradientColors: [
                        Color(red: 1.0,   green: 0.839, blue: 0.039),
                        Color(red: 1.0,   green: 0.624, blue: 0.039)
                    ]
                )
                .frame(maxWidth: .infinity)

                // Sommeil — lavande gradient (#A78BFA → #818CF8)
                RingMetricView(
                    label: "Récupération",
                    value: vm.lastNightSleep > 0 ? String(format: "%.1f h", vm.lastNightSleep) : "-- h",
                    progress: vm.sleepProgress,
                    gradientColors: [
                        Color(red: 0.655, green: 0.545, blue: 0.980),
                        Color(red: 0.506, green: 0.549, blue: 0.973)
                    ]
                )
                .frame(maxWidth: .infinity)

                // SpO2 — vert gradient (#86EFAC → #22C55E)
                RingMetricView(
                    label: "Sommeil",
                    value: vm.spo2Display.value,
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


// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView()
    }
}
