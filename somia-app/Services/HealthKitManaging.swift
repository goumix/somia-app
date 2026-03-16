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

    func requestAuthorization() async
    func fetchData() async
}
