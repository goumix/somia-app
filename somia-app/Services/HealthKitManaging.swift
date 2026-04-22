import HealthKit
import Observation
import SwiftUI

// MARK: - EffortSnapshot

struct EffortSnapshot {
    let exerciseMinutes: Double?
    let activeCalories: Double?
    let steps: Double?
    let peakHeartRate: Double?

    static let empty = EffortSnapshot(
        exerciseMinutes: nil, activeCalories: nil, steps: nil, peakHeartRate: nil
    )
}

// MARK: - Protocol

/// Interface commune à HealthKitManager et HealthKitManagerMock.
/// Injecté via .environment(\.healthKit) depuis somia_appApp.
protocol HealthKitManaging: AnyObject, Observable {
    var hrvSamples: [HKQuantitySample] { get }
    var sleepSamples: [HKCategorySample] { get }
    var authorizationStatus: String { get }
    var isLoading: Bool { get }
    var error: String? { get }
    var isAvailable: Bool { get }

    // MARK: - Tier 1
    var restingHeartRateSamples: [HKQuantitySample] { get }
    var spo2Samples: [HKQuantitySample] { get }
    var respiratoryRateSamples: [HKQuantitySample] { get }
    var stepSamples: [HKQuantitySample] { get }
    var vo2MaxSamples: [HKQuantitySample] { get }

    // MARK: - Tier 2
    var wristTemperatureSamples: [HKQuantitySample] { get }
    var timeInDaylightSamples: [HKQuantitySample] { get }
    var walkingHeartRateSamples: [HKQuantitySample] { get }

    // MARK: - Three months
    var hrvThreeMonthsSamples: [HKQuantitySample] { get }
    var hrvThreeMonthsValidWeekCount: Int { get }

    // MARK: - Yearly
    var hrvYearlySamples: [HKQuantitySample] { get }
    var hrvYearlyValidMonthCount: Int { get }

    // MARK: - Sleep Detail
    var sleepStart: Date? { get }
    var sleepEnd: Date? { get }
    var remDuration: TimeInterval { get }
    var deepDuration: TimeInterval { get }
    var nightlyHeartRateMin: Double? { get }
    var nightlyHeartRateAvg: Double? { get }
    var nightlyHeartRateMax: Double? { get }
    var nightlyHRDrop: Double? { get }

    var todayEffort: EffortSnapshot { get }

    @MainActor func requestAuthorization() async
    func fetchData() async
}

// MARK: - EnvironmentKey

private struct HealthKitEnvironmentKey: EnvironmentKey {
    static var defaultValue: any HealthKitManaging = HealthKitManager()
}

extension EnvironmentValues {
    var healthKit: any HealthKitManaging {
        get { self[HealthKitEnvironmentKey.self] }
        set { self[HealthKitEnvironmentKey.self] = newValue }
    }
}
