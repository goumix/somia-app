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

    var respiratoryRateDisplay: String {
        guard let sample = healthKit.respiratoryRateSamples.first else { return "--" }
        let rpm = sample.quantity.doubleValue(for: bpmUnit)
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

    let scoreResult: RecoveryScoreCalculator.Result?

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
                ScoreDonutView(data: scoreResult?.donutData(), size: 200)
                    .padding(.vertical, 8)
                HStack(spacing: 12) {
                    MetricCell(label: "HRV au repos", value: hrvDisplay)
                    MetricCell(label: "FC au repos",  value: rhrDisplay)
                }
                MetricCell(label: "Fréquence respiratoire", value: vm?.respiratoryRateDisplay ?? "--")
                HStack(spacing: 12) {
                    MetricCell(label: "SpO2",                value: vm?.spo2Display ?? "--")
                    MetricCell(label: "Écart temp. poignet", value: vm?.wristTempDisplay ?? "--")
                }
                if let r = scoreResult {
                    scoreBreakdownCard(r)
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

    private func scoreBreakdownCard(_ r: RecoveryScoreCalculator.Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Détail du score")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            VStack(spacing: 8) {
                breakdownRow(label: "HRV",                  pts: r.hrvPoints,   max: 35, color: .somiaAccent)
                breakdownRow(label: "FC repos",             pts: r.rhrPoints,   max: 25, color: .somiaGreenSoft)
                breakdownRow(label: "Sommeil",              pts: r.sleepPoints, max: 25, color: .somiaWarn)
                breakdownRow(label: "SpO2 / Fréq. respi.", pts: r.spo2Points + r.respiPoints, max: 15, color: .white.opacity(0.4))
                if r.coherenceMalus > 0 {
                    HStack {
                        Text("Malus cohérence SNA")
                            .font(.caption)
//                            .foregroundStyle(.somiaDrift)
                        Spacer()
                        Text("−\(r.coherenceMalus)")
                            .font(.caption.bold())
//                            .foregroundStyle(.somiaDrift)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func breakdownRow(label: String, pts: Int, max: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 130, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(pts) / CGFloat(max))
                }
            }
            .frame(height: 6)
            Text("\(pts)/\(max)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40, alignment: .trailing)
        }
    }
}
