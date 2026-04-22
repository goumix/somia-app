import Foundation
import HealthKit

struct RecoveryScoreCalculator {

    struct Result {
        let total: Int
        let hrvPoints: Int       // weighted contribution 0–35
        let rhrPoints: Int       // weighted contribution 0–25
        let sleepPoints: Int     // weighted contribution 0–25
        let spo2Points: Int      // weighted contribution 0–10
        let respiPoints: Int     // weighted contribution 0–5
        let coherenceMalus: Int  // 0 or 10
        let label: String
    }

    /// Returns nil when all bio inputs are nil (no overnight data).
    static func score(
        latestHRV: Double?,
        hrv60dMedian: Double?,
        latestRHR: Double?,
        rhr60dMedian: Double?,
        sleepScore: Int?,
        minNocturnalSpO2: Double?,   // HKit percent unit: 0.0–1.0
        latestRespiRate: Double?,
        respi60dMedian: Double?
    ) -> Result? {
        let hasAnyData = latestHRV != nil || latestRHR != nil || sleepScore != nil
        guard hasAnyData else { return nil }

        // — HRV component (0–100)
        let hrvRaw: Double
        let hrvRatio: Double
        if let h = latestHRV, let b = hrv60dMedian, b > 0 {
            hrvRatio = h / b
            hrvRaw   = hrvComponent(ratio: hrvRatio)
        } else {
            hrvRatio = 1.0
            hrvRaw   = 50
        }

        // — RHR component (0–100)
        let rhrDelta: Double
        let rhrRaw: Double
        if let r = latestRHR, let b = rhr60dMedian {
            rhrDelta = r - b
            rhrRaw   = rhrComponent(delta: rhrDelta)
        } else {
            rhrDelta = 0
            rhrRaw   = 50
        }

        // — Sleep component (0–100) — already 0–100 from SleepScoreCalculator
        let sleepRaw: Double = sleepScore.map { Double($0) } ?? 50

        // — SpO2 component (0–100)
        let spo2Raw: Double
        if let s = minNocturnalSpO2 {
            spo2Raw = spo2Component(minPct: s)
        } else {
            spo2Raw = 100
        }

        // — Respiratory rate component (0–100)
        let respiRaw: Double
        if let r = latestRespiRate, let b = respi60dMedian {
            respiRaw = respiComponent(delta: r - b)
        } else {
            respiRaw = 50
        }

        // — Coherence malus: RHR elevated AND HRV below baseline → ANS overload pattern
        let malus = (rhrDelta > 0 && hrvRatio < 1.0) ? 10 : 0

        // — Weighted sum
        let hrvW    = Int((hrvRaw  * 0.35).rounded())
        let rhrW    = Int((rhrRaw  * 0.25).rounded())
        let sleepW  = Int((sleepRaw * 0.25).rounded())
        let spo2W   = Int((spo2Raw * 0.10).rounded())
        let respiW  = Int((respiRaw * 0.05).rounded())

        let raw   = hrvW + rhrW + sleepW + spo2W + respiW - malus
        let total = max(0, min(100, raw))

        return Result(
            total: total,
            hrvPoints: hrvW,
            rhrPoints: rhrW,
            sleepPoints: sleepW,
            spo2Points: spo2W,
            respiPoints: respiW,
            coherenceMalus: malus,
            label: label(for: total)
        )
    }

    // MARK: - Components

    private static func hrvComponent(ratio: Double) -> Double {
        switch ratio {
        case 1.0...:    return 100
        case 0.9..<1.0: return 75  + (ratio - 0.9)  / 0.1 * 25
        case 0.8..<0.9: return 40  + (ratio - 0.8)  / 0.1 * 35
        case 0.7..<0.8: return       (ratio - 0.7)  / 0.1 * 40
        default:        return 0
        }
    }

    private static func rhrComponent(delta: Double) -> Double {
        switch delta {
        case ..<0:    return 100
        case 0..<3:   return 100 - delta / 3.0 * 30
        case 3..<6:   return 70  - (delta - 3) / 3.0 * 35
        case 6..<10:  return 35  - (delta - 6) / 4.0 * 35
        default:      return 0
        }
    }

    // minPct is in HKit percent unit: 0.97 means 97%
    private static func spo2Component(minPct: Double) -> Double {
        if minPct >= 0.96 { return 100 }
        if minPct >= 0.94 { return 60 }
        if minPct >= 0.92 { return 20 }
        return 0
    }

    private static func respiComponent(delta: Double) -> Double {
        switch delta {
        case ..<0:   return 100
        case 0..<1:  return 100 - delta * 30
        case 1..<2:  return 70  - (delta - 1) * 35
        case 2..<3:  return 35  - (delta - 2) * 35
        default:     return 0
        }
    }

    // MARK: - Label

    static func label(for score: Int) -> String {
        switch score {
        case 80...: return "Récupération optimale"
        case 60...: return "Bonne récupération"
        case 40...: return "Récupération partielle"
        case 20...: return "Récupération insuffisante"
        default:    return "Récupération critique"
        }
    }
}
