//
//  DashboardView.swift
//  somia-app
//
//  Created by Nathéo Brault on 23/03/2026.
//

import SwiftUI
import HealthKit
import Charts

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

// MARK: - SleepScoreRingView

private struct SleepScoreRingView: View {
    let result: SleepScoreCalculator.Result?
    let label: String

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

    private let ringSize: CGFloat = 96

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Chart(segments) { seg in
                    SectorMark(
                        angle: .value("pts", seg.points),
                        innerRadius: .ratio(0.72),
                        angularInset: result != nil ? 2.5 : 0
                    )
                    .foregroundStyle(seg.color)
                }
                .frame(width: ringSize, height: ringSize)

                Text(result.map { "\($0.total)" } ?? "--")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.somiaBodyText)
        }
    }
}

// MARK: - DashboardView

struct DashboardView: View {

    // MARK: - Environment

    @Environment(\.healthKit) private var healthKit

    // MARK: - ViewModel

    @AppStorage("userName") private var userName: String = "Alex"

    @State private var vm: DashboardViewModel?

    @State private var showSettings = false

    // MARK: - Helpers

    private var weeklyPoints: [DriftEvolutionCard.WeeklyPoint] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<13).compactMap { i -> DriftEvolutionCard.WeeklyPoint? in
            let validatorOffset = 12 - i  // 12 = oldest week, 0 = current week
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -validatorOffset, to: now),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { return nil }
            let samplesInWeek = healthKit.hrvThreeMonthsSamples.filter {
                $0.startDate >= interval.start && $0.startDate < interval.end
            }
            return DriftEvolutionCard.WeeklyPoint(
                weekOffset: i,
                score: 0, // TODO: replace score: 0 with real drift score per week
                isSufficient: samplesInWeek.count >= 5
            )
        }
    }

    private var yearlyMonths: [DriftYearCard.MonthlyPoint] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMM"

        return Array((0..<12).reversed()).compactMap { monthOffset -> DriftYearCard.MonthlyPoint? in
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let interval = calendar.dateInterval(of: .month, for: monthStart) else { return nil }
            let samplesInMonth = healthKit.hrvYearlySamples.filter {
                $0.startDate >= interval.start && $0.startDate < interval.end
            }
            let isSufficient = samplesInMonth.count >= 5
            let label = String(formatter.string(from: interval.start).prefix(3)).capitalized
            return DriftYearCard.MonthlyPoint(
                monthLabel: label,
                score: 0, // TODO: replace score: 0 with real drift score per month
                isSufficient: isSufficient
            )
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: Date()).uppercased()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somiaBackground.ignoresSafeArea()

                if let vm {
                    if vm.isLoading {
                        ProgressView()
                            .tint(Color.somiaAccent)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                headerSection(vm: vm)
                                todaySection(vm: vm)
                                cardGroupLabel("ÉTAT PHYSIOLOGIQUE · 1 MOIS")
                                DriftScoreCard(compositeScore: vm.compositeScore)
                                cardGroupLabel("ÉVOLUTION · 3 MOIS")
                                DriftEvolutionCard(points: weeklyPoints)
                                cardGroupLabel("TRAJECTOIRE · 1 AN")
                                DriftYearCard(months: yearlyMonths)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .task {
                if vm == nil {
                    vm = DashboardViewModel(healthKit: healthKit)
                }
                await vm?.requestAuthorization()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .tint(Color.somiaAccent)
    }

    // MARK: - Header Section

    private func headerSection(vm: DashboardViewModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                // Date in small caps style
                Text(formattedDate)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.somiaBodyText)
                    .tracking(1.2)

                Text("Bonjour \(userName)")
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
                    Text(String(userName.prefix(1)).uppercased())
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

    private func todaySection(vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AUJOURD'HUI")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(1.5)

            HStack(spacing: 0) {
                // Effort — score dédié 0–100 (algorithme à implémenter)
                NavigationLink(destination: EffortDetailView(qualityScore: vm.effortScore.map { Int($0) })) {
                    ScoreRingView(score: vm.effortScore, label: "Effort")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                // Récupération — score dédié 0–100 (algorithme à implémenter)
                NavigationLink(destination: RecoveryDetailView(qualityScore: vm.recoveryScore.map { Int($0) })) {
                    ScoreRingView(score: vm.recoveryScore, label: "Récupération")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                // Sommeil — segmented donut via SleepScoreCalculator
                NavigationLink(destination: SleepDetailView(qualityScore: vm.sleepScore.map { Int($0) })) {
                    SleepScoreRingView(result: vm.sleepScoreResult, label: "Sommeil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
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
