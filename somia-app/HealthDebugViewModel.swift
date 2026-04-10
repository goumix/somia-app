//
//  HealthDebugViewModel.swift
//  somia-app
//
//  Created by Nathéo Brault on 10/04/2026.
//

import SwiftUI
import HealthKit

@Observable
final class HealthDebugViewModel {

    // MARK: - Dependencies

    private let healthKit: HealthKitManaging

    // MARK: - Init

    init(healthKit: HealthKitManaging = HealthKitManager.shared) {
        self.healthKit = healthKit
    }

    // MARK: - Forwarded state

    var isLoading: Bool          { healthKit.isLoading }
    var isAvailable: Bool        { healthKit.isAvailable }
    var authorizationStatus: String { healthKit.authorizationStatus }
    var error: String?           { healthKit.error }

    /// Raw HRV samples forwarded for table display (date + formatted value).
    var hrvSamples: [HKQuantitySample]      { healthKit.hrvSamples }
    /// Raw sleep samples forwarded for table display.
    var sleepSamples: [HKCategorySample]    { healthKit.sleepSamples }

    // MARK: - Private: HKUnit constants

    private let msUnit      = HKUnit.secondUnit(with: .milli)
    private let bpmUnit     = HKUnit.count().unitDivided(by: .minute())
    private let percentUnit = HKUnit.percent()
    private let countUnit   = HKUnit.count()
    private let vo2Unit     = HKUnit(from: "ml/kg*min")
    private let celsiusUnit = HKUnit.degreeCelsius()
    private let minuteUnit  = HKUnit.minute()

    // MARK: - Date ranges

    var last30Days: ClosedRange<Date> {
        let now = Date()
        return (Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now)...now
    }

    var last90Days: ClosedRange<Date> {
        let now = Date()
        return (Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now)...now
    }

    // MARK: - Data — HRV (30 days)

    var hrvPoints: [(date: Date, value: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return healthKit.hrvSamples
            .filter { $0.startDate >= cutoff }
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: msUnit)) }
            .sorted { $0.date < $1.date }
    }

    var hrvAvg: Double { pointsAvg(hrvPoints) }
    var hrvMin: Double { hrvPoints.map(\.value).min() ?? 0 }
    var hrvMax: Double { hrvPoints.map(\.value).max() ?? 0 }

    // MARK: - Data — Sleep (30 nights)

    var sleepNights: [(date: Date, hours: Double)] {
        let cutoff   = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let calendar = Calendar.current
        let sleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        var byNight: [Date: Double] = [:]
        for s in healthKit.sleepSamples where sleepValues.contains(s.value) && s.startDate >= cutoff {
            let night = calendar.startOfDay(for: s.startDate)
            byNight[night, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 3600
        }
        return byNight.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    var sleepAvg: Double {
        guard !sleepNights.isEmpty else { return 0 }
        return sleepNights.map(\.hours).reduce(0, +) / Double(sleepNights.count)
    }
    var sleepBadNights: Int    { sleepNights.filter { $0.hours < 6 }.count }
    var sleepBest: Double      { sleepNights.map(\.hours).max() ?? 0 }

    // MARK: - Data — Tier 1

    var rhrPoints: [(date: Date, value: Double)] {
        healthKit.restingHeartRateSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: bpmUnit)) }
            .sorted { $0.date < $1.date }
    }
    var rhrAvg: Double { pointsAvg(rhrPoints) }
    var rhrMin: Double { rhrPoints.map(\.value).min() ?? 0 }
    var rhrMax: Double { rhrPoints.map(\.value).max() ?? 0 }

    // SpO2 stored as fraction (0.97 = 97 %) — multiplied ×100 for display
    var spo2Points: [(date: Date, value: Double)] {
        healthKit.spo2Samples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: percentUnit) * 100) }
            .sorted { $0.date < $1.date }
    }
    var spo2Avg: Double { pointsAvg(spo2Points) }
    var spo2Min: Double { spo2Points.map(\.value).min() ?? 0 }
    var spo2Max: Double { spo2Points.map(\.value).max() ?? 0 }

    var respRatePoints: [(date: Date, value: Double)] {
        healthKit.respiratoryRateSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: bpmUnit)) }
            .sorted { $0.date < $1.date }
    }
    var respRateAvg: Double { pointsAvg(respRatePoints) }
    var respRateMin: Double { respRatePoints.map(\.value).min() ?? 0 }
    var respRateMax: Double { respRatePoints.map(\.value).max() ?? 0 }

    // Steps aggregated per day (device may produce multiple samples/day)
    var stepDays: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for s in healthKit.stepSamples {
            let day = calendar.startOfDay(for: s.startDate)
            byDay[day, default: 0] += s.quantity.doubleValue(for: countUnit)
        }
        return byDay.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    var stepAvg: Double { pointsAvg(stepDays) }
    var stepMin: Double { stepDays.map(\.value).min() ?? 0 }
    var stepMax: Double { stepDays.map(\.value).max() ?? 0 }

    var vo2Points: [(date: Date, value: Double)] {
        healthKit.vo2MaxSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: vo2Unit)) }
            .sorted { $0.date < $1.date }
    }
    var vo2Avg: Double { pointsAvg(vo2Points) }
    var vo2Min: Double { vo2Points.map(\.value).min() ?? 0 }
    var vo2Max: Double { vo2Points.map(\.value).max() ?? 0 }

    // MARK: - Data — Tier 2

    // Wrist temp is a deviation in °C from nightly baseline; values centered around 0
    var wristTempPoints: [(date: Date, value: Double)] {
        healthKit.wristTemperatureSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: celsiusUnit)) }
            .sorted { $0.date < $1.date }
    }
    var wristTempAvg: Double { pointsAvg(wristTempPoints) }
    var wristTempMin: Double { wristTempPoints.map(\.value).min() ?? 0 }
    var wristTempMax: Double { wristTempPoints.map(\.value).max() ?? 0 }

    // Daylight aggregated per day
    var daylightDays: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for s in healthKit.timeInDaylightSamples {
            let day = calendar.startOfDay(for: s.startDate)
            byDay[day, default: 0] += s.quantity.doubleValue(for: minuteUnit)
        }
        return byDay.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    var daylightAvg: Double { pointsAvg(daylightDays) }
    var daylightMin: Double { daylightDays.map(\.value).min() ?? 0 }
    var daylightMax: Double { daylightDays.map(\.value).max() ?? 0 }

    var walkingHRPoints: [(date: Date, value: Double)] {
        healthKit.walkingHeartRateSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: bpmUnit)) }
            .sorted { $0.date < $1.date }
    }
    var walkingHRAvg: Double { pointsAvg(walkingHRPoints) }
    var walkingHRMin: Double { walkingHRPoints.map(\.value).min() ?? 0 }
    var walkingHRMax: Double { walkingHRPoints.map(\.value).max() ?? 0 }

    // MARK: - Formatters (use units privately)

    /// Formats a raw HRV sample value for display in the table view.
    func formattedHRVSample(_ sample: HKQuantitySample) -> String {
        String(format: "%.1f ms", sample.quantity.doubleValue(for: msUnit))
    }

    func sleepLabel(_ value: Int) -> String {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed:             return "Au lit"
        case .asleepUnspecified: return "Endormi (non spécifié)"
        case .awake:             return "Éveillé"
        case .asleepCore:        return "Sommeil léger"
        case .asleepDeep:        return "Sommeil profond"
        case .asleepREM:         return "Sommeil REM"
        default:                 return "Inconnu (\(value))"
        }
    }

    /// "8 500" below 10 k, "10 k" above — keeps y-axis labels short.
    func stepsLabel(_ v: Double) -> String {
        v >= 10_000 ? String(format: "%.0f k", v / 1_000) : "\(Int(v))"
    }

    // MARK: - Color helpers

    func colorForSleep(_ hours: Double) -> Color {
        if hours < 6 { return Color(red: 1, green: 0.267, blue: 0.267) } // #FF4444
        if hours < 7 { return Color(red: 1, green: 0.584, blue: 0)     } // #FF9500
        return Color(red: 0, green: 0.784, blue: 0.588)                   // #00C896
    }

    func colorForSteps(_ steps: Double) -> Color {
        if steps < 5_000  { return Color(red: 1, green: 0.267, blue: 0.267) }
        if steps < 10_000 { return Color(red: 1.0, green: 0.584, blue: 0.0) }
        return Color(red: 0, green: 0.784, blue: 0.588)
    }

    func colorForDaylight(_ minutes: Double) -> Color {
        minutes < 30
            ? Color(red: 1.0, green: 0.584, blue: 0.0)   // orange
            : Color(red: 1.0, green: 0.8,   blue: 0.0)   // yellow
    }

    // MARK: - Actions

    func fetchData() async {
        await healthKit.fetchData()
    }

    // MARK: - Private helpers

    private func pointsAvg(_ points: [(date: Date, value: Double)]) -> Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }
}
