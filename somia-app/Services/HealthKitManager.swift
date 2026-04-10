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

    // MARK: - Tier 1

    var restingHeartRateSamples: [HKQuantitySample] = []
    var spo2Samples: [HKQuantitySample] = []
    var respiratoryRateSamples: [HKQuantitySample] = []
    var stepSamples: [HKQuantitySample] = []
    var vo2MaxSamples: [HKQuantitySample] = []

    // MARK: - Tier 2

    var wristTemperatureSamples: [HKQuantitySample] = []
    var timeInDaylightSamples: [HKQuantitySample] = []
    var walkingHeartRateSamples: [HKQuantitySample] = []

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    init() {}

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else {
            error = "HealthKit non disponible sur cet appareil"
            return
        }

        var typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.sleepAnalysis),
            // Tier 1
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.vo2Max),
            // Tier 2 — broadly available
            HKQuantityType(.walkingHeartRateAverage)
        ]

        // Tier 2 — guarded by OS availability
        if #available(iOS 16, *) {
            typesToRead.insert(HKQuantityType(.appleSleepingWristTemperature))
        }
        if #available(iOS 17, *) {
            typesToRead.insert(HKQuantityType(.timeInDaylight))
        }

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
        // Tier 1
        async let rhr = fetchRestingHeartRate()
        async let spo2 = fetchSpO2()
        async let respRate = fetchRespiratoryRate()
        async let steps = fetchStepCount()
        async let vo2Max = fetchVO2Max()
        // Tier 2
        async let wristTemp = fetchWristTemperature()
        async let daylight = fetchTimeInDaylight()
        async let walkingHR = fetchWalkingHeartRate()

        let (hrvResult, sleepResult) = await (hrv, sleep)
        let (rhrResult, spo2Result, respRateResult, stepsResult, vo2MaxResult) =
            await (rhr, spo2, respRate, steps, vo2Max)
        let (wristTempResult, daylightResult, walkingHRResult) =
            await (wristTemp, daylight, walkingHR)

        hrvSamples = hrvResult
        sleepSamples = sleepResult
        restingHeartRateSamples = rhrResult
        spo2Samples = spo2Result
        respiratoryRateSamples = respRateResult
        stepSamples = stepsResult
        vo2MaxSamples = vo2MaxResult
        wristTemperatureSamples = wristTempResult
        timeInDaylightSamples = daylightResult
        walkingHeartRateSamples = walkingHRResult
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

    // MARK: - Tier 1

    private func fetchRestingHeartRate() async -> [HKQuantitySample] {
        let type = HKQuantityType(.restingHeartRate)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    private func fetchSpO2() async -> [HKQuantitySample] {
        let type = HKQuantityType(.oxygenSaturation)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    private func fetchRespiratoryRate() async -> [HKQuantitySample] {
        let type = HKQuantityType(.respiratoryRate)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    private func fetchStepCount() async -> [HKQuantitySample] {
        let type = HKQuantityType(.stepCount)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    private func fetchVO2Max() async -> [HKQuantitySample] {
        let type = HKQuantityType(.vo2Max)
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date()) // 90-day window — slow signal
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    // MARK: - Tier 2

    private func fetchWristTemperature() async -> [HKQuantitySample] {
        guard #available(iOS 16, *) else { return [] }
        let type = HKQuantityType(.appleSleepingWristTemperature)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    private func fetchTimeInDaylight() async -> [HKQuantitySample] {
        guard #available(iOS 17, *) else { return [] }
        let type = HKQuantityType(.timeInDaylight)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    private func fetchWalkingHeartRate() async -> [HKQuantitySample] {
        let type = HKQuantityType(.walkingHeartRateAverage)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor: HKSampleQueryDescriptor<HKQuantitySample> = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }
}
