import Foundation
import HealthKit

// Disponible uniquement sur le simulateur
#if targetEnvironment(simulator)

// MARK: - PhysioProfile

/// Profils physiologiques prédéfinis pour tester rapidement les différents états de l'app.
/// Chaque profil définit une contribution HRV et une contribution Sommeil au score composite.
enum PhysioProfile: CaseIterable {
    case optimalRecovery, progression, stable, mildDrift, mentalOverload, severeDrift

    var label: String {
        switch self {
        case .optimalRecovery: return "Récupération optimale"
        case .progression:     return "En progression"
        case .stable:          return "Stable"
        case .mildDrift:       return "Dérive légère"
        case .mentalOverload:  return "Surcharge mentale"
        case .severeDrift:     return "Dérive sévère"
        }
    }

    /// Contribution HRV au score composite, en points [-50, +50].
    var hrvContrib: Double {
        switch self {
        case .optimalRecovery: return  40
        case .progression:     return  20
        case .stable:          return   0
        case .mildDrift:       return -20
        case .mentalOverload:  return -35
        case .severeDrift:     return -48
        }
    }

    /// Contribution sommeil au score composite, en points [-50, +50].
    var sleepContrib: Double {
        switch self {
        case .optimalRecovery: return  25   // ~9.5h sleep
        case .progression:     return  12   // ~8.5h sleep
        case .stable:          return   0   // ~7.5h sleep
        case .mildDrift:       return -12   // ~6.5h sleep
        case .mentalOverload:  return -20   // ~5.9h sleep
        case .severeDrift:     return -45   // ~4.0h sleep
        }
    }

    /// Score composite total attendu (indicatif).
    var totalScore: Int { Int(hrvContrib + sleepContrib) }
    // optimalRecovery: +65  → "En progression forte"
    // progression:     +32  → "En progression"
    // stable:            0  → "Stable"
    // mildDrift:       -32  → "En dérive légère"
    // mentalOverload:  -55  → "En dérive modérée"
    // severeDrift:     -93  → "En dérive sévère"
}

// MARK: - HealthKitManagerMock

@Observable
final class HealthKitManagerMock: HealthKitManaging {

    // MARK: - Score Contributions (-50 pts dérive … +50 pts progression)

    /// Contribution de l'HRV au score composite, en points.
    var hrvScoreContribution: Double = 0
    /// Contribution du sommeil au score composite, en points.
    var sleepScoreContribution: Double = 0

    // MARK: - HealthKit Data

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

    // MARK: - Sleep Detail

    var sleepStart: Date?
    var sleepEnd: Date?
    var remDuration: TimeInterval = 6720    // 1h 52min
    var deepDuration: TimeInterval = 2580   // 43min
    var nightlyHeartRateMin: Double? = 48
    var nightlyHeartRateAvg: Double? = 56
    var nightlyHeartRateMax: Double? = 72
    var nightlyHRDrop: Double? = 38.5

    // MARK: - Three months

    var hrvThreeMonthsSamples: [HKQuantitySample] = []

    var hrvThreeMonthsValidWeekCount: Int {
        let calendar = Calendar.current
        let now = Date()
        var count = 0
        for weekOffset in 0..<13 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }
            let samplesInWeek = hrvThreeMonthsSamples.filter {
                $0.startDate >= interval.start && $0.startDate < interval.end
            }
            if samplesInWeek.count >= 5 { count += 1 }
        }
        return count
    }

    // MARK: - Yearly

    var hrvYearlySamples: [HKQuantitySample] = []

    var hrvYearlyValidMonthCount: Int {
        let calendar = Calendar.current
        let now = Date()
        var count = 0
        for monthOffset in 0..<12 {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let interval = calendar.dateInterval(of: .month, for: monthStart) else { continue }
            let samplesInMonth = hrvYearlySamples.filter {
                $0.startDate >= interval.start && $0.startDate < interval.end
            }
            if samplesInMonth.count >= 5 { count += 1 }
        }
        return count
    }

    init() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let yesterday = cal.date(byAdding: .day, value: -1, to: today) {
            sleepStart = cal.date(bySettingHour: 23, minute: 10, second: 0, of: yesterday)
        }
        sleepEnd = cal.date(bySettingHour: 6, minute: 45, second: 0, of: today)

        hrvSamples              = Self.makeHRVSamples()
        sleepSamples            = Self.makeSleepSamples()
        restingHeartRateSamples = Self.makeRestingHeartRateSamples()
        spo2Samples             = Self.makeSpO2Samples()
        respiratoryRateSamples  = Self.makeRespiratoryRateSamples()
        stepSamples             = Self.makeStepSamples()
        vo2MaxSamples           = Self.makeVO2MaxSamples()
        wristTemperatureSamples  = Self.makeWristTemperatureSamples()
        timeInDaylightSamples    = Self.makeTimeInDaylightSamples()
        walkingHeartRateSamples  = Self.makeWalkingHeartRateSamples()
        hrvThreeMonthsSamples    = Self.makeHRVThreeMonthsSamples()
        hrvYearlySamples         = Self.makeHRVYearlySamples()
    }

    @MainActor func requestAuthorization() async {
        authorizationStatus = "Autorisé"
        await fetchData()
    }

    func fetchData() async {
        isLoading = true
        try? await Task.sleep(for: .milliseconds(600))
        hrvSamples              = Self.makeHRVSamples(contribution: hrvScoreContribution)
        sleepSamples            = Self.makeSleepSamples(contribution: sleepScoreContribution)
        restingHeartRateSamples = Self.makeRestingHeartRateSamples()
        spo2Samples             = Self.makeSpO2Samples()
        respiratoryRateSamples  = Self.makeRespiratoryRateSamples()
        stepSamples             = Self.makeStepSamples()
        vo2MaxSamples           = Self.makeVO2MaxSamples()
        wristTemperatureSamples  = Self.makeWristTemperatureSamples()
        timeInDaylightSamples    = Self.makeTimeInDaylightSamples()
        walkingHeartRateSamples  = Self.makeWalkingHeartRateSamples()
        hrvThreeMonthsSamples    = Self.makeHRVThreeMonthsSamples()
        hrvYearlySamples         = Self.makeHRVYearlySamples()
        isLoading = false
    }

    /// Applique un profil physiologique prédéfini et recharge les données.
    func applyProfile(_ profile: PhysioProfile) async {
        hrvScoreContribution   = profile.hrvContrib
        sleepScoreContribution = profile.sleepContrib
        await fetchData()
    }

    // MARK: - HRV — 89 jours de baseline stable + 1 jour contrôlé

    /// Génère 89 jours d'historique HRV stable (~42–58 ms) puis injecte un sample
    /// "hier" dont la valeur est calculée pour produire exactement `contribution` points
    /// dans le score composite HRV.
    ///
    /// Formule exacte (évite le biais dû à l'inclusion du sample contrôlé dans la moyenne) :
    ///   latestHRV = n × avg89 × (1 + c) / (n − c)   où c = contribution / 200, n = 89
    private static func makeHRVSamples(contribution: Double = 0) -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.heartRateVariabilitySDNN)
        let unit     = HKUnit.secondUnit(with: .milli)
        var rng      = SeededRNG(seed: 0xDEAD_BEEF)

        // 89 jours stables (days -90 … -2)
        var history: [HKQuantitySample] = []
        for offset in 0..<89 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(90 - offset), to: today),
                let start = calendar.date(bySettingHour: 3,
                                          minute: Int.random(in: 0...29, using: &rng),
                                          second: 0, of: day),
                let end   = calendar.date(byAdding: .minute, value: 5, to: start)
            else { continue }

            let hrv = Double.random(in: 42...58, using: &rng)
            history.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: hrv),
                start: start, end: end
            ))
        }

        // Moyenne de l'historique (déterministe grâce au seed)
        let n      = Double(history.count)
        let avg89  = history.map { $0.quantity.doubleValue(for: unit) }.reduce(0, +) / n
        let c      = max(-0.99, min(0.99, contribution / 200.0)) // guard division
        let latest = max(15, min(120, n * avg89 * (1 + c) / (n - c)))

        // Sample "hier" avec la valeur exacte cible
        var samples = history
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let start     = calendar.date(bySettingHour: 3, minute: 15, second: 0, of: yesterday),
           let end       = calendar.date(byAdding: .minute, value: 5, to: start) {
            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: latest),
                start: start, end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Sleep — 89 nuits historiques + 1 nuit contrôlée

    /// Génère 89 nuits d'historique aléatoires puis injecte une dernière nuit
    /// dont la durée réelle de sommeil correspond exactement à la contribution cible :
    ///   targetHours = 7.5 + contribution / 12.5
    private static func makeSleepSamples(contribution: Double = 0) -> [HKCategorySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKCategoryType(.sleepAnalysis)
        var rng      = SeededRNG(seed: 0xC0FFEE_42)

        var samples: [HKCategorySample] = []

        // 89 nuits historiques (days -90 … -2)
        for offset in 0..<89 {
            guard
                let day     = calendar.date(byAdding: .day, value: -(90 - offset), to: today),
                let bedTime = calendar.date(
                    bySettingHour: Int.random(in: 22...23, using: &rng),
                    minute: Int.random(in: 0...59, using: &rng),
                    second: 0, of: day)
            else { continue }

            let totalMin = Int.random(in: 330...540, using: &rng)
            let wakeTime = bedTime.addingTimeInterval(Double(totalMin) * 60)

            samples.append(HKCategorySample(
                type: type,
                value: HKCategoryValueSleepAnalysis.inBed.rawValue,
                start: bedTime, end: wakeTime
            ))

            var cursor = bedTime
            while cursor < wakeTime {
                let remainingMins = Int(wakeTime.timeIntervalSince(cursor) / 60)
                guard remainingMins >= 5 else { break }
                let segMins = remainingMins < 15
                    ? remainingMins
                    : Int.random(in: 15...min(remainingMins, 90), using: &rng)
                let segEnd = cursor.addingTimeInterval(Double(segMins) * 60)
                samples.append(HKCategorySample(
                    type: type,
                    value: randomPhase(offset: offset, cursor: cursor, bedTime: bedTime, using: &rng).rawValue,
                    start: cursor, end: segEnd
                ))
                cursor = segEnd
            }
        }

        // Dernière nuit (hier) avec durée exacte correspondant à la contribution
        let targetHours   = max(2.0, min(12.0, 7.5 + contribution / 12.5))
        let targetSeconds = targetHours * 3_600

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let bedTime   = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday) {
            let wakeTime = bedTime.addingTimeInterval(targetSeconds)
            samples.append(HKCategorySample(
                type: type,
                value: HKCategoryValueSleepAnalysis.inBed.rawValue,
                start: bedTime, end: wakeTime
            ))
            // Un seul segment asleepCore pour que lastNightSleep soit exact
            samples.append(HKCategorySample(
                type: type,
                value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                start: bedTime, end: wakeTime
            ))
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
        let elapsed = cursor.timeIntervalSince(bedTime) / 3600
        let roll    = Int.random(in: 0..<100, using: &rng)

        if elapsed < 3 {
            switch roll {
            case 0..<40:  return .asleepCore
            case 40..<65: return .asleepDeep
            case 65..<90: return .asleepREM
            default:      return .awake
            }
        } else {
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

            var rhr = Double.random(in: 55...65, using: &rng)
            if offset >= 20 {
                rhr -= Double(offset - 20) * 0.2
            }

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: max(52, min(68, rhr))),
                start: start, end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Tier 1 — SpO2 — 30 days, 96–99 %

    private static func makeSpO2Samples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let type     = HKQuantityType(.oxygenSaturation)
        let unit     = HKUnit.percent()
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
                start: start, end: end
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

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: Double.random(in: 14...18, using: &rng)),
                start: start, end: end
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

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: Double.random(in: 6_000...12_000, using: &rng).rounded()),
                start: start, end: end
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
        var weekOffset = 0
        while weekOffset < 90 {
            guard
                let day   = calendar.date(byAdding: .day, value: -(90 - weekOffset), to: today),
                let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day),
                let end   = calendar.date(byAdding: .minute, value: 30, to: start)
            else { weekOffset += 7; continue }

            let vo2 = max(40, min(52, Double.random(in: 42...48, using: &rng) + Double(weekOffset / 7) * 0.05))
            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: vo2),
                start: start, end: end
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

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: Double.random(in: -0.3...0.3, using: &rng)),
                start: start, end: end
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

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: Double.random(in: 20...90, using: &rng)),
                start: start, end: end
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

            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: Double.random(in: 90...105, using: &rng)),
                start: start, end: end
            ))
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Three-month HRV — 6 samples per week, 13 weeks (all weeks sufficient)

    /// Generates 6 nightly HRV samples for each of the past 13 calendar weeks,
    /// evenly spread across each week. Every week exceeds the 5-sample threshold
    /// so `isSufficient` is true for all weeks in the evolution card.
    private static func makeHRVThreeMonthsSamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let now = Date()
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let unit = HKUnit.secondUnit(with: .milli)
        var rng = SeededRNG(seed: 0xC0CA_C01A)

        var samples: [HKQuantitySample] = []

        for weekOffset in 0..<13 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }

            for sampleIndex in 0..<6 {
                let dayOffset = sampleIndex  // one sample per day, days 0–5
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: interval.start),
                      let start = calendar.date(bySettingHour: 3,
                                                minute: Int.random(in: 0...59, using: &rng),
                                                second: 0, of: day),
                      let end = calendar.date(byAdding: .minute, value: 5, to: start) else { continue }

                let hrv = Double.random(in: 38...65, using: &rng)
                samples.append(HKQuantitySample(
                    type: type,
                    quantity: HKQuantity(unit: unit, doubleValue: hrv),
                    start: start, end: end
                ))
            }
        }

        return samples.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Yearly HRV — 8 samples per month, 12 months (all months sufficient)

    /// Generates 8 nightly HRV samples for each of the past 12 calendar months,
    /// evenly spread across each month. Every month exceeds the 5-sample threshold
    /// so `isSufficient` is true for all months in the year card.
    private static func makeHRVYearlySamples() -> [HKQuantitySample] {
        let calendar = Calendar.current
        let now = Date()
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let unit = HKUnit.secondUnit(with: .milli)
        var rng = SeededRNG(seed: 0xD00D_FEED)

        var samples: [HKQuantitySample] = []

        for monthOffset in 0..<12 {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let interval = calendar.dateInterval(of: .month, for: monthStart) else { continue }

            for sampleIndex in 0..<8 {
                let dayOffset = Int(Double(sampleIndex) / 8.0 * 28.0)
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: interval.start),
                      let start = calendar.date(bySettingHour: 3,
                                                minute: Int.random(in: 0...59, using: &rng),
                                                second: 0, of: day),
                      let end = calendar.date(byAdding: .minute, value: 5, to: start) else { continue }

                let hrv = Double.random(in: 38...65, using: &rng)
                samples.append(HKQuantitySample(
                    type: type,
                    quantity: HKQuantity(unit: unit, doubleValue: hrv),
                    start: start, end: end
                ))
            }
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
