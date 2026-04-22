//
//  SleepDetailView.swift
//  somia-app
//
//  Created by Nathéo Brault on 10/04/2026.
//

import SwiftUI
import HealthKit

// MARK: - ViewModel

@Observable
private final class SleepViewModel {

    let healthKit: any HealthKitManaging

    init(healthKit: any HealthKitManaging) {
        self.healthKit = healthKit
    }

    // MARK: - Score (SpO2 du jour, déjà en %, exprimé comme score 0–100)

    func score(for date: Date) -> Double? {
        let cal = Calendar.current
        guard let sample = healthKit.spo2Samples.first(where: { cal.isDate($0.startDate, inSameDayAs: date) })
        else { return nil }
        return sample.quantity.doubleValue(for: .percent()) * 100
    }

    // MARK: - Plages horaires et phases (nuit la plus récente)

    var sleepPeriodDisplay: String {
        guard let start = healthKit.sleepStart, let end = healthKit.sleepEnd else { return "--" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: start)) — \(fmt.string(from: end))"
    }

    var remDisplay: String {
        healthKit.remDuration > 0 ? formatPhaseDuration(healthKit.remDuration) : "--"
    }

    var deepDisplay: String {
        healthKit.deepDuration > 0 ? formatPhaseDuration(healthKit.deepDuration) : "--"
    }

    var nightlyHRMinDisplay: String {
        healthKit.nightlyHeartRateMin.map { "\(Int($0))" } ?? "--"
    }

    var nightlyHRAvgDisplay: String {
        healthKit.nightlyHeartRateAvg.map { "\(Int($0.rounded()))" } ?? "--"
    }

    var nightlyHRMaxDisplay: String {
        healthKit.nightlyHeartRateMax.map { "\(Int($0))" } ?? "--"
    }

    var hrDropDisplay: String {
        healthKit.nightlyHRDrop.map { "\($0)%" } ?? "--"
    }

    private func formatPhaseDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(mins)min" : "\(mins)min"
    }

    // MARK: - Sleep Score

    func sleepScore(for date: Date) -> SleepScoreCalculator.Result? {
        let cal = Calendar.current
        guard let previousDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date)) else { return nil }
        let nightSamples = healthKit.sleepSamples.filter {
            cal.isDate($0.startDate, inSameDayAs: previousDay)
        }
        return SleepScoreCalculator.score(nightSamples: nightSamples, historicalStarts: historicalBedtimes())
    }

    private func historicalBedtimes() -> [Date] {
        let cal = Calendar.current
        var byDay: [Date: Date] = [:]
        for sample in healthKit.sleepSamples {
            let day = cal.startOfDay(for: sample.startDate)
            if byDay[day] == nil || sample.startDate < byDay[day]! {
                byDay[day] = sample.startDate
            }
        }
        return Array(byDay.values).sorted()
    }

    // MARK: - Métriques sommeil (nuit précédant date)

    func sleepData(for date: Date) -> (inBed: Double?, asleep: Double?) {
        let cal = Calendar.current
        guard let previousDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))
        else { return (nil, nil) }

        let nightSamples = healthKit.sleepSamples.filter {
            cal.isDate($0.startDate, inSameDayAs: previousDay)
        }

        let inBedSamples = nightSamples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
        let asleepStates: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        let asleepSamples = nightSamples.filter { asleepStates.contains($0.value) }

        let inBedHours  = inBedSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 }
        let asleepHours = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 }

        return (
            inBedSamples.isEmpty  ? nil : inBedHours,
            asleepSamples.isEmpty ? nil : asleepHours
        )
    }
}

// MARK: - View

struct SleepDetailView: View {

    let qualityScore: Int?

    @Environment(\.healthKit) private var healthKit
    @State private var vm: SleepViewModel?
    @State private var selectedDate: Date = .init()
    @State private var showDatePicker = false

    private var inBedDisplay: String {
        guard let vm else { return "--" }
        guard let hours = vm.sleepData(for: selectedDate).inBed else { return "--" }
        return formatDuration(hours)
    }

    private var asleepDisplay: String {
        guard let vm else { return "--" }
        guard let hours = vm.sleepData(for: selectedDate).asleep else { return "--" }
        return formatDuration(hours)
    }

    private func formatDuration(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        return "\(totalMinutes / 60)h \(totalMinutes % 60)min"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                datePicker
                ScoreDonutView(data: vm?.sleepScore(for: selectedDate)?.donutData(), size: 200)
                    .padding(.vertical, 8)
                HStack(spacing: 12) {
                    MetricCell(label: "Temps au lit",       value: inBedDisplay)
                    MetricCell(label: "Durée du sommeil",   value: asleepDisplay)
                }
                sleepPeriodCard
                HStack(spacing: 12) {
                    MetricCell(label: "Sommeil paradoxal", value: vm?.remDisplay ?? "--")
                    MetricCell(label: "Sommeil profond",   value: vm?.deepDisplay ?? "--")
                }
                nightlyHeartRateCard
                hrDropCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.somiaBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Sommeil")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .onAppear { vm = vm ?? SleepViewModel(healthKit: healthKit) }
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

    private var sleepPeriodCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bed.double")
                .font(.body)
                .foregroundStyle(.white.opacity(0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text("Période de sommeil")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text(vm?.sleepPeriodDisplay ?? "--")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var nightlyHeartRateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FC nocturne")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            HStack {
                Spacer()
                hrValueColumn(label: "Min", value: vm?.nightlyHRMinDisplay ?? "--")
                Spacer()
                hrValueColumn(label: "Moy", value: vm?.nightlyHRAvgDisplay ?? "--")
                Spacer()
                hrValueColumn(label: "Max", value: vm?.nightlyHRMaxDisplay ?? "--")
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func hrValueColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("bpm")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var hrDropCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Baisse de fréquence cardiaque")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text(vm?.hrDropDisplay ?? "--")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("par rapport à la FC de repos")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
