import HealthKit
import Observation

/// Interface commune à HealthKitManager et HealthKitManagerMock.
/// Utilisée pour l'injection de dépendance via #if targetEnvironment(simulator).
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

    func requestAuthorization() async
    func fetchData() async
}
