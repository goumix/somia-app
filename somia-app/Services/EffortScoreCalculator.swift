import Foundation

struct EffortScoreCalculator {

    struct Result {
        let total: Int
        let stepsPoints: Int     // weighted contribution 0–35
        let exercisePoints: Int  // weighted contribution 0–35
        let caloriesPoints: Int  // weighted contribution 0–20
        let hrPoints: Int        // weighted contribution 0–10
        let label: String
    }

    /// Returns nil when all inputs are nil.
    static func score(
        steps: Double?,
        exerciseMinutes: Double?,
        activeCalories: Double?,
        peakHR: Double?,
        rhrBaseline: Double?
    ) -> Result? {
        guard steps != nil || exerciseMinutes != nil || activeCalories != nil else { return nil }

        let stepsRaw    = stepsComponent(steps: steps ?? 0)
        let exerciseRaw = exerciseComponent(minutes: exerciseMinutes ?? 0)
        let caloriesRaw = caloriesComponent(kcal: activeCalories ?? 0)
        let hrRaw       = hrComponent(peakHR: peakHR, rhrBaseline: rhrBaseline)

        let stepsW    = Int((stepsRaw    * 0.35).rounded())
        let exerciseW = Int((exerciseRaw * 0.35).rounded())
        let caloriesW = Int((caloriesRaw * 0.20).rounded())
        let hrW       = Int((hrRaw       * 0.10).rounded())

        let total = max(0, min(100, stepsW + exerciseW + caloriesW + hrW))

        return Result(
            total: total,
            stepsPoints: stepsW,
            exercisePoints: exerciseW,
            caloriesPoints: caloriesW,
            hrPoints: hrW,
            label: label(for: total)
        )
    }

    // MARK: - Components

    private static func stepsComponent(steps: Double) -> Double {
        switch steps {
        case 12_000...: return 100
        case 8_000..<12_000: return 70 + (steps - 8_000) / 4_000 * 30
        case 5_000..<8_000:  return 35 + (steps - 5_000) / 3_000 * 35
        default:             return steps / 5_000 * 35
        }
    }

    private static func exerciseComponent(minutes: Double) -> Double {
        switch minutes {
        case 60...:    return 100
        case 30..<60:  return 60 + (minutes - 30) / 30 * 40
        case 15..<30:  return 30 + (minutes - 15) / 15 * 30
        default:       return minutes / 15 * 30
        }
    }

    private static func caloriesComponent(kcal: Double) -> Double {
        switch kcal {
        case 600...:    return 100
        case 300..<600: return 50  + (kcal - 300) / 300 * 50
        case 100..<300: return      (kcal - 100) / 200 * 50
        default:        return 0
        }
    }

    // Neutral (50) when data unavailable — avoids penalising rest days
    private static func hrComponent(peakHR: Double?, rhrBaseline: Double?) -> Double {
        guard let peak = peakHR, let rhr = rhrBaseline else { return 50 }
        let delta = peak - rhr
        switch delta {
        case 60...:    return 100
        case 40..<60:  return 80 + (delta - 40) / 20 * 20
        case 20..<40:  return      (delta - 20) / 20 * 80
        default:       return 0
        }
    }

    // MARK: - Label

    static func label(for score: Int) -> String {
        switch score {
        case 80...: return "Effort très intense"
        case 60...: return "Effort intense"
        case 40...: return "Effort modéré"
        case 20...: return "Effort léger"
        default:    return "Repos"
        }
    }
}
