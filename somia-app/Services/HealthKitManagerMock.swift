import Foundation
import HealthKit

// Disponible uniquement sur le simulateur
#if targetEnvironment(simulator)

@Observable
final class HealthKitManagerMock: HealthKitManaging {

    var hrvSamples: [HKQuantitySample] = []
    var sleepSamples: [HKCategorySample] = []
    var authorizationStatus: String = "Autorisé"
    var isLoading: Bool = false
    var error: String? = nil
    var isAvailable: Bool { true }

    init() {
        hrvSamples = Self.makeHRVSamples()
        sleepSamples = Self.makeSleepSamples()
    }

    func requestAuthorization() async {
        authorizationStatus = "Autorisé"
        await fetchData()
    }

    func fetchData() async {
        isLoading = true
        try? await Task.sleep(for: .milliseconds(600))
        hrvSamples = Self.makeHRVSamples()
        sleepSamples = Self.makeSleepSamples()
        isLoading = false
    }

    // MARK: - VFC — 90 jours, 35–65 ms, dérive à la baisse sur les 14 derniers jours

    private static func makeHRVSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.heartRateVariabilitySDNN)
        let unit     = HKUnit.secondUnit(with: .milli)
        var rng      = SeededRNG(seed: 0xDEAD_BEEF)

        var samples: [HKQuantitySample] = []

        for offset in 0..<90 {
            // offset 0 = il y a 90 jours ; offset 89 = hier
            guard
                let day   = calendar.date(byAdding: .day, value: -(90 - offset), to: today),
                let start = calendar.date(bySettingHour: 3,
                                          minute: Int.random(in: 0...29, using: &rng),
                                          second: 0, of: day),
                let end   = calendar.date(byAdding: .minute, value: 5, to: start)
            else { continue }

            // Valeur de base : aléatoire entre 35 et 65 ms
            var hrv = Double.random(in: 35...65, using: &rng)

            // Dérive physiologique sur les 14 derniers jours (offset 76–89) : ≈ −4 ms au total
            if offset >= 76 {
                hrv -= Double(offset - 76) * 0.29
            }

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: max(20, min(80, hrv))),
                start: start,
                end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Sommeil — 90 nuits, 5 h 30 – 9 h, phases aléatoires

    private static func makeSleepSamples() -> [HKCategorySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKCategoryType(.sleepAnalysis)
        var rng      = SeededRNG(seed: 0xC0FFEE_42)

        var samples: [HKCategorySample] = []

        for offset in 0..<90 {
            guard
                let day     = calendar.date(byAdding: .day, value: -(90 - offset), to: today),
                let bedTime = calendar.date(
                    bySettingHour: Int.random(in: 22...23, using: &rng),
                    minute: Int.random(in: 0...59, using: &rng),
                    second: 0, of: day)
            else { continue }

            // Durée totale : 5 h 30 – 9 h  (330 – 540 min)
            let totalMin = Int.random(in: 330...540, using: &rng)
            let wakeTime = bedTime.addingTimeInterval(Double(totalMin) * 60)

            // Segment global « Au lit »
            samples.append(HKCategorySample(
                type: type,
                value: HKCategoryValueSleepAnalysis.inBed.rawValue,
                start: bedTime,
                end: wakeTime
            ))

            // Phases de sommeil
            var cursor = bedTime
            while cursor < wakeTime {
                let remainingMins = Int(wakeTime.timeIntervalSince(cursor) / 60)
                guard remainingMins >= 5 else { break }

                let segMins: Int
                if remainingMins < 15 {
                    segMins = remainingMins
                } else {
                    segMins = Int.random(in: 15...min(remainingMins, 90), using: &rng)
                }

                let segEnd = cursor.addingTimeInterval(Double(segMins) * 60)
                samples.append(HKCategorySample(
                    type: type,
                    value: randomPhase(offset: offset, cursor: cursor, bedTime: bedTime, using: &rng).rawValue,
                    start: cursor,
                    end: segEnd
                ))
                cursor = segEnd
            }
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    /// Distribution inspirée de l'architecture réelle du sommeil :
    /// plus de sommeil profond en début de nuit, plus de REM en fin.
    private static func randomPhase(
        offset: Int,
        cursor: Date,
        bedTime: Date,
        using rng: inout SeededRNG
    ) -> HKCategoryValueSleepAnalysis {
        let elapsed = cursor.timeIntervalSince(bedTime) / 3600 // heures depuis le coucher
        let roll = Int.random(in: 0..<100, using: &rng)

        if elapsed < 3 {
            // Première moitié : plus de sommeil profond
            switch roll {
            case 0..<40:  return .asleepCore
            case 40..<65: return .asleepDeep
            case 65..<90: return .asleepREM
            default:      return .awake
            }
        } else {
            // Seconde moitié : plus de REM
            switch roll {
            case 0..<45:  return .asleepCore
            case 45..<55: return .asleepDeep
            case 55..<92: return .asleepREM
            default:      return .awake
            }
        }
    }
}

// MARK: - Xorshift64 RNG déterministe

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

#endif
