//
//  DashboardView.swift
//  somia-app
//
//  Created by Nathéo Brault on 23/03/2026.
//

import SwiftUI
import HealthKit
import Charts

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
                // Effort — strain du jour via EffortScoreCalculator
                NavigationLink(destination: EffortDetailView(scoreResult: vm.effortScoreResult)) {
                    VStack(spacing: 10) {
                        ScoreDonutView(data: vm.effortScoreResult?.donutData())
                        Text("Effort")
                            .font(.somiaCaption)
                            .foregroundStyle(Color.somiaBodyText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                // Récupération — score nocturne via RecoveryScoreCalculator
                NavigationLink(destination: RecoveryDetailView(scoreResult: vm.recoveryScoreResult)) {
                    VStack(spacing: 10) {
                        ScoreDonutView(data: vm.recoveryScoreResult?.donutData())
                        Text("Récupération")
                            .font(.somiaCaption)
                            .foregroundStyle(Color.somiaBodyText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                // Sommeil — segmented donut via SleepScoreCalculator
                NavigationLink(destination: SleepDetailView(qualityScore: vm.sleepScore.map { Int($0) })) {
                    VStack(spacing: 10) {
                        ScoreDonutView(data: vm.sleepScoreResult?.donutData())
                        Text("Sommeil")
                            .font(.somiaCaption)
                            .foregroundStyle(Color.somiaBodyText)
                    }
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
