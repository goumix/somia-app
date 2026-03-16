import Foundation
import HealthKit

@Observable
final class HealthKitManager: HealthKitManaging {

    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    var hrvSamples: [HKQuantitySample] = []
    var sleepSamples: [HKCategorySample] = []
    var authorizationStatus: String = "Non demandé"
    var isLoading = false
    var error: String?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else {
            error = "HealthKit non disponible sur cet appareil"
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.sleepAnalysis)
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: typesToRead)
            authorizationStatus = "Autorisé"
            await fetchData()
        } catch {
            authorizationStatus = "Refusé"
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch

    func fetchData() async {
        isLoading = true
        error = nil

        async let hrv = fetchHRV()
        async let sleep = fetchSleep()

        let (hrvResult, sleepResult) = await (hrv, sleep)

        hrvSamples = hrvResult
        sleepSamples = sleepResult
        isLoading = false
    }

    private func fetchHRV() async -> [HKQuantitySample] {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    private func fetchSleep() async -> [HKCategorySample] {
        let type = HKCategoryType(.sleepAnalysis)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKCategorySample> = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }
}
