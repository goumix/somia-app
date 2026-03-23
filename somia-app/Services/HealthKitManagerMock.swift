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

    init() {
        hrvSamples = Self.makeHRVSamples()
        sleepSamples = Self.makeSleepSamples()
        restingHeartRateSamples = Self.makeRestingHeartRateSamples()
        spo2Samples = Self.makeSpO2Samples()
        respiratoryRateSamples = Self.makeRespiratoryRateSamples()
        stepSamples = Self.makeStepSamples()
        vo2MaxSamples = Self.makeVO2MaxSamples()
        wristTemperatureSamples = Self.makeWristTemperatureSamples()
        timeInDaylightSamples = Self.makeTimeInDaylightSamples()
        walkingHeartRateSamples = Self.makeWalkingHeartRateSamples()
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
        restingHeartRateSamples = Self.makeRestingHeartRateSamples()
        spo2Samples = Self.makeSpO2Samples()
        respiratoryRateSamples = Self.makeRespiratoryRateSamples()
        stepSamples = Self.makeStepSamples()
        vo2MaxSamples = Self.makeVO2MaxSamples()
        wristTemperatureSamples = Self.makeWristTemperatureSamples()
        timeInDaylightSamples = Self.makeTimeInDaylightSamples()
        walkingHeartRateSamples = Self.makeWalkingHeartRateSamples()
        isLoading = false
    }

    // MARK: - HRV — 90 jours, 35–65 ms, dérive à la baisse sur les 14 derniers jours

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

    // MARK: - Sleep — 90 nuits, 5 h 30 – 9 h, phases aléatoires

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

    // MARK: - Tier 1 — Resting Heart Rate — 30 days, 55–65 bpm, slight downward trend

    private static func makeRestingHeartRateSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.restingHeartRate)
        let unit     = HKUnit.count().unitDivided(by: .minute())
        var rng      = SeededRNG(seed: 0xABCD_1234)

        var samples: [HKQuantitySample] = []

        for offset in 0..<30 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(30 - offset), to: today),
                let start = calendar.date(bySettingHour: 6,
                                          minute: Int.random(in: 0...30, using: &rng),
                                          second: 0, of: day),
                let end   = calendar.date(byAdding: .minute, value: 1, to: start)
            else { continue }

            // Base 55–65 bpm; slight improvement trend over last 10 days (−0.2 bpm/day)
            var rhr = Double.random(in: 55...65, using: &rng)
            if offset >= 20 {
                rhr -= Double(offset - 20) * 0.2
            }

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: max(52, min(68, rhr))),
                start: start,
                end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Tier 1 — SpO2 — 30 days, 96–99 %

    private static func makeSpO2Samples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.oxygenSaturation)
        let unit     = HKUnit.percent() // stored as fraction: 0.97 = 97 %
        var rng      = SeededRNG(seed: 0x5A70_B3C1)

        var samples: [HKQuantitySample] = []

        for offset in 0..<30 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(30 - offset), to: today),
                let start = calendar.date(bySettingHour: 3,
                                          minute: Int.random(in: 0...59, using: &rng),
                                          second: 0, of: day),
                let end   = calendar.date(byAdding: .minute, value: 2, to: start)
            else { continue }

            let spo2 = Double.random(in: 0.96...0.99, using: &rng)

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: spo2),
                start: start,
                end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Tier 1 — Respiratory Rate — 30 days, 14–18 breaths/min

    private static func makeRespiratoryRateSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.respiratoryRate)
        let unit     = HKUnit.count().unitDivided(by: .minute())
        var rng      = SeededRNG(seed: 0xF1E2_D3C4)

        var samples: [HKQuantitySample] = []

        for offset in 0..<30 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(30 - offset), to: today),
                let start = calendar.date(bySettingHour: 4,
                                          minute: Int.random(in: 0...59, using: &rng),
                                          second: 0, of: day),
                let end   = calendar.date(byAdding: .minute, value: 2, to: start)
            else { continue }

            let rate = Double.random(in: 14...18, using: &rng)

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: rate),
                start: start,
                end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Tier 1 — Step Count — 30 days, 6 000–12 000 steps/day

    private static func makeStepSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.stepCount)
        let unit     = HKUnit.count()
        var rng      = SeededRNG(seed: 0x9B8A_7C6D)

        var samples: [HKQuantitySample] = []

        for offset in 0..<30 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(30 - offset), to: today),
                let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day),
                let end   = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day)
            else { continue }

            let steps = Double.random(in: 6_000...12_000, using: &rng)

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: steps.rounded()),
                start: start,
                end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Tier 1 — VO2max — 90 days, 42–48 ml/kg/min (slow signal, measured ~weekly)

    private static func makeVO2MaxSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.vo2Max)
        let unit     = HKUnit(from: "ml/kg*min")
        var rng      = SeededRNG(seed: 0x3E4F_5A6B)

        var samples: [HKQuantitySample] = []

        // One measurement per week over 90 days (~13 samples)
        var weekOffset = 0
        while weekOffset < 90 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(90 - weekOffset), to: today),
                let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day),
                let end   = calendar.date(byAdding: .minute, value: 30, to: start)
            else {
                weekOffset += 7
                continue
            }

            // Slight upward fitness trend over 90 days (+0.05 ml/kg/min per week)
            let base = Double.random(in: 42...48, using: &rng)
            let trend = Double(weekOffset / 7) * 0.05
            let vo2 = max(40, min(52, base + trend))

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: vo2),
                start: start,
                end: end
            ))

            weekOffset += 7
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Tier 2 — Wrist Temperature — 30 days, deviation ±0.3 °C from baseline

    private static func makeWristTemperatureSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.appleSleepingWristTemperature)
        let unit     = HKUnit.degreeCelsius()
        var rng      = SeededRNG(seed: 0x7C8D_9EAF)

        var samples: [HKQuantitySample] = []

        for offset in 0..<30 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(30 - offset), to: today),
                let start = calendar.date(bySettingHour: 3,
                                          minute: Int.random(in: 0...59, using: &rng),
                                          second: 0, of: day),
                let end   = calendar.date(byAdding: .hour, value: 6, to: start)
            else { continue }

            // Deviation from nightly baseline: typically −0.3 to +0.3 °C
            let deviation = Double.random(in: -0.3...0.3, using: &rng)

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: deviation),
                start: start,
                end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Tier 2 — Time in Daylight — 30 days, 20–90 min/day

    private static func makeTimeInDaylightSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.timeInDaylight)
        let unit     = HKUnit.minute()
        var rng      = SeededRNG(seed: 0x1B2C_3D4E)

        var samples: [HKQuantitySample] = []

        for offset in 0..<30 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(30 - offset), to: today),
                let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day),
                let end   = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day)
            else { continue }

            let minutes = Double.random(in: 20...90, using: &rng)

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: minutes),
                start: start,
                end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Tier 2 — Walking Heart Rate Average — 30 days, 90–105 bpm

    private static func makeWalkingHeartRateSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.walkingHeartRateAverage)
        let unit     = HKUnit.count().unitDivided(by: .minute())
        var rng      = SeededRNG(seed: 0xE5F6_0718)

        var samples: [HKQuantitySample] = []

        for offset in 0..<30 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(30 - offset), to: today),
                let start = calendar.date(bySettingHour: 12,
                                          minute: Int.random(in: 0...30, using: &rng),
                                          second: 0, of: day),
                let end   = calendar.date(byAdding: .minute, value: 30, to: start)
            else { continue }

            let bpm = Double.random(in: 90...105, using: &rng)

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: bpm),
                start: start,
                end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
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
