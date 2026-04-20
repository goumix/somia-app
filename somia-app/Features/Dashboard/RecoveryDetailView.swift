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

    private var progress: Double  { qualityScore.map { Double($0) / 100.0 } ?? 0.0 }
    private var ringColor: Color  { qualityScore.map { Color.scoreColor(for: Double($0)) } ?? .somiaBodyText }

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
            Text(qualityScore.map { "\($0)" } ?? "--")
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
