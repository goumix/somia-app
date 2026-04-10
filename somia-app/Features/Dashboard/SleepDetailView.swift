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

    @Environment(\.healthKit) private var healthKit
    @State private var vm: SleepViewModel?
    @State private var selectedDate: Date = .init()
    @State private var showDatePicker = false

    private var score: Double?    { vm?.score(for: selectedDate) }
    private var progress: Double  { (score ?? 0) / 100.0 }
    private var ringColor: Color  { score.map { scoreColor(for: $0) } ?? ringNeutralColor }

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
                scoreRing
                HStack(spacing: 12) {
                    metricCard(label: "Temps au lit",       value: inBedDisplay)
                    metricCard(label: "Durée du sommeil",   value: asleepDisplay)
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
