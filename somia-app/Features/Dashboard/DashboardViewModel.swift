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

    // MARK: - Private units

    private let msUnit  = HKUnit.secondUnit(with: .milli)
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    private let pctUnit = HKUnit.percent()

    // MARK: - Computed: HRV

    var latestHRV: Double? {
        healthKit.hrvSamples.first.map { $0.quantity.doubleValue(for: msUnit) }
    }

    var hrvAvg30: Double {
        guard !healthKit.hrvSamples.isEmpty else { return 0 }
        let values = healthKit.hrvSamples.map { $0.quantity.doubleValue(for: msUnit) }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Computed: Sleep

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

    // MARK: - Baseline helper: 60-day rolling median

    private func median60d(_ samples: [HKQuantitySample], unit: HKUnit) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        var values = samples
            .filter { $0.startDate >= cutoff }
            .map { $0.quantity.doubleValue(for: unit) }
            .sorted()
        guard !values.isEmpty else { return nil }
        return values[values.count / 2]
    }

    // MARK: - Composite drift score [-100, +100]

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

    // MARK: - HRV score (0–100)

    var hrvScore: Double? {
        latestHRV.map { min($0 / 100.0, 1.0) * 100 }
    }

    // MARK: - Sleep score

    var sleepScoreResult: SleepScoreCalculator.Result? {
        SleepScoreCalculator.score(
            nightSamples: SleepScoreCalculator.lastNightSamples(from: healthKit.sleepSamples),
            historicalStarts: SleepScoreCalculator.historicalBedtimes(from: healthKit.sleepSamples)
        )
    }

    var sleepScore: Double? {
        sleepScoreResult.map { Double($0.total) }
    }

    // MARK: - Recovery score

    var recoveryScoreResult: RecoveryScoreCalculator.Result? {
        let latestHRV   = healthKit.hrvSamples.first.map { $0.quantity.doubleValue(for: msUnit) }
        let hrv60d      = median60d(healthKit.hrvSamples, unit: msUnit)
        let latestRHR   = healthKit.restingHeartRateSamples.first.map { $0.quantity.doubleValue(for: bpmUnit) }
        let rhr60d      = median60d(healthKit.restingHeartRateSamples, unit: bpmUnit)
        let sleepSc     = sleepScoreResult?.total
        let minSpO2     = nocturnalSpO2Min()
        let latestRespi = healthKit.respiratoryRateSamples.first.map { $0.quantity.doubleValue(for: bpmUnit) }
        let respi60d    = median60d(healthKit.respiratoryRateSamples, unit: bpmUnit)

        return RecoveryScoreCalculator.score(
            latestHRV: latestHRV,
            hrv60dMedian: hrv60d,
            latestRHR: latestRHR,
            rhr60dMedian: rhr60d,
            sleepScore: sleepSc,
            minNocturnalSpO2: minSpO2,
            latestRespiRate: latestRespi,
            respi60dMedian: respi60d
        )
    }

    var recoveryScore: Double? { recoveryScoreResult.map { Double($0.total) } }
    var recoveryProgress: Double { (recoveryScore ?? 0) / 100.0 }

    // SpO2 minimum from last 12 hours (nocturnal window)
    private func nocturnalSpO2Min() -> Double? {
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        let recent = healthKit.spo2Samples.filter { $0.startDate >= cutoff }
        guard !recent.isEmpty else {
            return healthKit.spo2Samples.first.map { $0.quantity.doubleValue(for: pctUnit) }
        }
        return recent.map { $0.quantity.doubleValue(for: pctUnit) }.min()
    }

    // MARK: - Effort score

    private(set) var effortScoreResult: EffortScoreCalculator.Result?

    var effortScore: Double? { effortScoreResult.map { Double($0.total) } }
    var effortProgress: Double { (effortScore ?? 0) / 100.0 }

    func loadEffortScore() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let exerciseType = HKQuantityType(.appleExerciseTime)
        let energyType   = HKQuantityType(.activeEnergyBurned)
        let stepsType    = HKQuantityType(.stepCount)
        let hrType       = HKQuantityType(.heartRate)

        let cal   = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        let pred  = HKQuery.predicateForSamples(withStart: start, end: end)

        let store = HKHealthStore()
        async let ex    = fetchQuantity(type: exerciseType, predicate: pred, store: store)
        async let kcal  = fetchQuantity(type: energyType,   predicate: pred, store: store)
        async let steps = fetchQuantity(type: stepsType,    predicate: pred, store: store)
        async let hr    = fetchQuantity(type: hrType,       predicate: pred, store: store)
        let (exSamples, kcalSamples, stepSamples, hrSamples) = await (ex, kcal, steps, hr)

        let exerciseMinutes = exSamples.isEmpty ? nil :
            exSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .minute()) }
        let activeCalories = kcalSamples.isEmpty ? nil :
            kcalSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
        let totalSteps = stepSamples.isEmpty ? nil :
            stepSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .count()) }
        let peakHR = hrSamples.isEmpty ? nil :
            hrSamples.map { $0.quantity.doubleValue(for: bpmUnit) }.max()

        effortScoreResult = EffortScoreCalculator.score(
            steps: totalSteps,
            exerciseMinutes: exerciseMinutes,
            activeCalories: activeCalories,
            peakHR: peakHR,
            rhrBaseline: median60d(healthKit.restingHeartRateSamples, unit: bpmUnit)
        )
    }

    private func fetchQuantity(
        type: HKQuantityType,
        predicate: NSPredicate,
        store: HKHealthStore
    ) async -> [HKQuantitySample] {
        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    // MARK: - Ring progress helpers

    var hrvProgress: Double { (hrvScore ?? 0) / 100.0 }
    var sleepProgress: Double { (sleepScore ?? 0) / 100.0 }

    // MARK: - Actions

    func requestAuthorization() async {
        await healthKit.requestAuthorization()
    }
}
