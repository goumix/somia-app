import Foundation
import HealthKit
import Accelerate

struct SleepScoreCalculator {

    struct Result {
        let total: Int
        let durationPoints: Int
        let bedtimePoints: Int
        let interruptionPoints: Int
        let label: String
    }

    /// Returns nil when nightSamples is empty (no data for the requested night).
    static func score(
        nightSamples: [HKCategorySample],
        historicalStarts: [Date]
    ) -> Result? {
        guard !nightSamples.isEmpty else { return nil }
        let dur   = durationScore(nightSamples)
        let bed   = bedtimeScore(nightSamples, historicalStarts: historicalStarts)
        let inter = interruptionScore(nightSamples)
        let total = dur + bed + inter
        return Result(
            total: total,
            durationPoints: dur,
            bedtimePoints: bed,
            interruptionPoints: inter,
            label: label(for: total)
        )
    }

    // MARK: - Duration 0–50 pts

    private static func durationScore(_ samples: [HKCategorySample]) -> Int {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let hours = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600.0 }

        let pts: Double
        if hours < 4.0 {
            // Severe non-linear penalty
            pts = 5.0 * pow(hours / 4.0, 2.0)
        } else if hours < 7.5 {
            // Convex progressive gain 5→50
            pts = 5.0 + 45.0 * pow((hours - 4.0) / 3.5, 1.5)
        } else {
            pts = 50.0
        }
        return Int(pts.rounded())
    }

    // MARK: - Bedtime 0–30 pts

    private static func bedtimeScore(_ samples: [HKCategorySample], historicalStarts: [Date]) -> Int {
        guard historicalStarts.count >= 5 else { return 15 }
        let cal = Calendar.current

        // Convert to minutes-from-midnight; normalize past-midnight starts (< 6h) forward by +24h
        var minutesArray: [Float] = historicalStarts.map { date in
            let c = cal.dateComponents([.hour, .minute], from: date)
            var m = Float((c.hour ?? 0) * 60 + (c.minute ?? 0))
            if m < 360 { m += 1440 }
            return m
        }
        vDSP.sort(&minutesArray, sortOrder: .ascending)
        let medianMinutes = minutesArray[minutesArray.count / 2]

        guard let bedStart = samples.map(\.startDate).min() else { return 15 }
        let c = cal.dateComponents([.hour, .minute], from: bedStart)
        var actual = Float((c.hour ?? 0) * 60 + (c.minute ?? 0))
        if actual < 360 { actual += 1440 }

        let delay = actual - medianMinutes
        if delay <= 15 {
            return 30
        } else if delay <= 60 {
            return Int((30.0 * Double(1.0 - (delay - 15.0) / 45.0)).rounded())
        } else {
            return 0
        }
    }

    // MARK: - Interruptions 0–20 pts

    private static func interruptionScore(_ samples: [HKCategorySample]) -> Int {
        let awakeMinutes = samples
            .filter { $0.value == HKCategoryValueSleepAnalysis.awake.rawValue }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }

        if awakeMinutes < 10 {
            return 20
        } else if awakeMinutes < 60 {
            return Int((20.0 * (1.0 - (awakeMinutes - 10.0) / 50.0)).rounded())
        } else {
            return 0
        }
    }

    // MARK: - Label

    static func label(for score: Int) -> String {
        switch score {
        case 85...: return "Excellent"
        case 70...: return "Très bon"
        case 55...: return "Bon"
        case 40...: return "Correct"
        case 20...: return "Faible"
        default:    return "Très faible"
        }
    }

    // MARK: - Extraction helpers

    /// All samples belonging to the most recent sleep night in the array.
    static func lastNightSamples(from samples: [HKCategorySample]) -> [HKCategorySample] {
        guard let latestStart = samples.map(\.startDate).max() else { return [] }
        let cal = Calendar.current
        let referenceDay = cal.startOfDay(for: latestStart)
        return samples.filter { cal.startOfDay(for: $0.startDate) == referenceDay }
    }

    /// One bedtime (earliest startDate) per calendar day — used to build the 30-day median baseline.
    static func historicalBedtimes(from samples: [HKCategorySample]) -> [Date] {
        let cal = Calendar.current
        var byDay: [Date: Date] = [:]
        for sample in samples {
            let day = cal.startOfDay(for: sample.startDate)
            if byDay[day] == nil || sample.startDate < byDay[day]! {
                byDay[day] = sample.startDate
            }
        }
        return Array(byDay.values).sorted()
    }
}
