//
//  DashboardViewModel.swift
//  somia-app
//
//  Created by Nathéo Brault on 10/04/2026.
//

import SwiftUI
import HealthKit

@Observable
final class DashboardViewModel {

    // MARK: - Dependencies

    private let healthKit: any HealthKitManaging

    // MARK: - Init

    init(healthKit: any HealthKitManaging) {
        self.healthKit = healthKit
    }

    // MARK: - Forwarded state

    var isLoading: Bool { healthKit.isLoading }

    // MARK: - Private

    private let msUnit = HKUnit.secondUnit(with: .milli)

    // MARK: - Computed: HRV

    /// Most recent HRV sample value (ms).
    var latestHRV: Double? {
        healthKit.hrvSamples.first.map { $0.quantity.doubleValue(for: msUnit) }
    }

    /// 30-day HRV mean used as baseline for scoring.
    var hrvAvg30: Double {
        guard !healthKit.hrvSamples.isEmpty else { return 0 }
        let values = healthKit.hrvSamples.map { $0.quantity.doubleValue(for: msUnit) }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Computed: Sleep

    /// Total sleep duration for the most recent night (in hours).
    var lastNightSleep: Double {
        let calendar = Calendar.current
        let actualSleepStates: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        var byNight: [Date: Double] = [:]
        for sample in healthKit.sleepSamples where actualSleepStates.contains(sample.value) {
            let night = calendar.startOfDay(for: sample.startDate)
            byNight[night, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
        }
        return byNight.sorted { $0.key > $1.key }.first?.value ?? 0
    }

    // MARK: - Computed: Composite Score

    /// Composite physiological drift score in [-100, +100].
    /// HRV contributes ±50 pts (based on deviation from 30-day mean).
    /// Sleep contributes ±50 pts (based on deviation from 7.5 h baseline).
    var compositeScore: Int {
        var score: Double = 0

        if let hrv = latestHRV, hrvAvg30 > 0 {
            let ratio = (hrv - hrvAvg30) / hrvAvg30
            score += min(50, max(-50, ratio * 200))
        }

        let sleep = lastNightSleep
        if sleep > 0 {
            score += min(50, max(-50, (sleep - 7.5) * 12.5))
        }

        return Int(min(100, max(-100, score)))
    }

    // MARK: - Normalized Scores (0–100)

    /// HRV mapped to 0–100. 100 ms → score 100 (capped).
    var hrvScore: Double? {
        latestHRV.map { min($0 / 100.0, 1.0) * 100 }
    }

    /// Sleep duration mapped to 0–100. 9 h → score 100 (capped).
    var sleepScore: Double? {
        guard lastNightSleep > 0 else { return nil }
        return min(lastNightSleep / 9.0, 1.0) * 100
    }

    /// SpO2 is already in % — exposed as a 0–100 score.
    var spo2Score: Double? { 98.0 }

    /// Score de récupération 0–100.
    /// TODO: remplacer par une formule basée sur HRV + FC repos.
    var recoveryScore: Double? { nil }

    var recoveryProgress: Double { (recoveryScore ?? 0) / 100.0 }

    // MARK: - Ring Progress

    var hrvProgress: Double { (hrvScore ?? 0) / 100.0 }

    var sleepProgress: Double { (sleepScore ?? 0) / 100.0 }

    // MARK: - Metric Display

    var spo2Display: (value: String, trend: String, trendColor: Color) {
        ("98 %", "Stable", Color.somiaBodyText)
    }

    // MARK: - Actions

    func requestAuthorization() async {
        await healthKit.requestAuthorization()
    }
}
