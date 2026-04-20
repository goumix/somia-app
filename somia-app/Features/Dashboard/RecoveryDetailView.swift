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

    // MARK: - Métriques

    func latestHRV(for date: Date) -> Double? {
        healthKit.hrvSamples
            .first { $0.startDate <= date }
            .map { $0.quantity.doubleValue(for: msUnit) }
    }

    func latestRHR(for date: Date) -> Double? {
        healthKit.restingHeartRateSamples
            .first { $0.startDate <= date }
            .map { $0.quantity.doubleValue(for: bpmUnit) }
    }

    // MARK: - Nouvelles métriques (sample le plus récent toutes dates)

    var respiratoryRateDisplay: String {
        guard let sample = healthKit.respiratoryRateSamples.first else { return "--" }
        let rpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        return String(format: "%.1f rpm", rpm)
    }

    var spo2Display: String {
        guard let sample = healthKit.spo2Samples.first else { return "--" }
        let pct = sample.quantity.doubleValue(for: .percent()) * 100
        return String(format: "%.1f %%", pct)
    }

    var wristTempDisplay: String {
        guard let sample = healthKit.wristTemperatureSamples.first else { return "--" }
        let delta = sample.quantity.doubleValue(for: .degreeCelsius())
        let sign = delta >= 0 ? "+" : ""
        return String(format: "\(sign)%.2f °C", delta)
    }
}

// MARK: - View

struct RecoveryDetailView: View {

    let qualityScore: Int?

    @Environment(\.healthKit) private var healthKit
    @State private var vm: RecoveryViewModel?
    @State private var selectedDate: Date = .init()
    @State private var showDatePicker = false

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
                ScoreRingView(score: qualityScore.map(Double.init), size: 200)
                    .padding(.vertical, 8)
                HStack(spacing: 12) {
                    metricCard(label: "HRV au repos", value: hrvDisplay)
                    metricCard(label: "FC au repos",  value: rhrDisplay)
                }
                metricCard(label: "Fréquence respiratoire", value: vm?.respiratoryRateDisplay ?? "--")
                HStack(spacing: 12) {
                    metricCard(label: "SpO2",                 value: vm?.spo2Display ?? "--")
                    metricCard(label: "Écart temp. poignet",  value: vm?.wristTempDisplay ?? "--")
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
