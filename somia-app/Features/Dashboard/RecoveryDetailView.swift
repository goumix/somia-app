//
//  RecoveryDetailView.swift
//  somia-app
//
//  Created by Nathéo Brault on 10/04/2026.
//

import SwiftUI
import HealthKit

// MARK: - ViewModel

@Observable
private final class RecoveryViewModel {

    let healthKit: any HealthKitManaging
    private let msUnit  = HKUnit.secondUnit(with: .milli)
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    init(healthKit: any HealthKitManaging) {
        self.healthKit = healthKit
    }

    // MARK: - Score (sommeil de la nuit précédant date, normalisé 0–100)

    func score(for date: Date) -> Double? {
        let hours = sleepHours(for: date)
        guard hours > 0 else { return nil }
        return min(hours / 9.0, 1.0) * 100
    }

    // MARK: - Métriques

    func latestHRV(for date: Date) -> Double? {
        let cal = Calendar.current
        return healthKit.hrvSamples
            .first { cal.isDate($0.startDate, inSameDayAs: date) }
            .map { $0.quantity.doubleValue(for: msUnit) }
    }

    func latestRHR(for date: Date) -> Double? {
        let cal = Calendar.current
        return healthKit.restingHeartRateSamples
            .first { cal.isDate($0.startDate, inSameDayAs: date) }
            .map { $0.quantity.doubleValue(for: bpmUnit) }
    }

    // MARK: - Private

    private func sleepHours(for date: Date) -> Double {
        let cal = Calendar.current
        guard let previousDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date)) else { return 0 }
        let asleepStates: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        return healthKit.sleepSamples
            .filter { cal.isDate($0.startDate, inSameDayAs: previousDay) && asleepStates.contains($0.value) }
            .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 }
    }
}

// MARK: - View

struct RecoveryDetailView: View {

    @Environment(\.healthKit) private var healthKit
    @State private var vm: RecoveryViewModel?
    @State private var selectedDate: Date = .init()
    @State private var showDatePicker = false

    private var score: Double?    { vm?.score(for: selectedDate) }
    private var progress: Double  { (score ?? 0) / 100.0 }
    private var ringColor: Color  { score.map { scoreColor(for: $0) } ?? ringNeutralColor }

    private var hrvDisplay: String {
        guard let vm, let hrv = vm.latestHRV(for: selectedDate) else { return "--" }
        return String(format: "%.1f ms", hrv)
    }

    private var rhrDisplay: String {
        guard let vm, let rhr = vm.latestRHR(for: selectedDate) else { return "--" }
        return String(format: "%.1f bpm", rhr)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                datePicker
                scoreRing
                HStack(spacing: 12) {
                    metricCard(label: "HRV au repos", value: hrvDisplay)
                    metricCard(label: "FC au repos",  value: rhrDisplay)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.somiaBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Récupération")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .onAppear { vm = vm ?? RecoveryViewModel(healthKit: healthKit) }
    }

    // MARK: - Subviews

    private var datePicker: some View {
        Button { showDatePicker.toggle() } label: {
            HStack(spacing: 6) {
                Text(selectedDate.formatted(.dateTime.day().month(.wide).year()))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .presentationDetents([.medium])
                .tint(Color.somiaAccent)
        }
    }

    private var scoreRing: some View {
        let size: CGFloat = 200
        let lw:   CGFloat = 20
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lw)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.7), value: progress)
                .shadow(color: ringColor.opacity(0.4), radius: 12)
            Text(score.map { "\(Int($0))" } ?? "--")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .padding(.vertical, 8)
    }

    private func metricCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
