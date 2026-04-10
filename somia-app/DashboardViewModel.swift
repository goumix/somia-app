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

    // `internal` (not private) so DashboardView can forward the mock to SettingsView
    // on the simulator — the only caller is the #if targetEnvironment(simulator) block.
    let healthKit: HealthKitManaging

    // MARK: - Init

    init(healthKit: HealthKitManaging = HealthKitManager.shared) {
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

    // MARK: - Ring Progress

    var hrvProgress: Double {
        guard let hrv = latestHRV, hrvAvg30 > 0 else { return 0 }
        return min(1.0, max(0.0, hrv / hrvAvg30))
    }

    var sleepProgress: Double {
        guard lastNightSleep > 0 else { return 0 }
        return min(1.0, max(0.0, lastNightSleep / 8.0))
    }

    // MARK: - Metric Display

    var spo2Display: (value: String, trend: String, trendColor: Color) {
        ("98 %", "Stable", Color.somiaBodyText)
    }

    // MARK: - Actions

    func requestAuthorization() async {
        await healthKit.requestAuthorization()
    }
}
