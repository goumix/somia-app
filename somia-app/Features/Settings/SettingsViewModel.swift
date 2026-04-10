//
//  SettingsViewModel.swift
//  somia-app
//
//  Created by Nathéo Brault on 10/04/2026.
//

import SwiftUI

@Observable
final class SettingsViewModel {

    // MARK: - Dependencies

    private let healthKit: any HealthKitManaging

    // MARK: - Init

    init(healthKit: any HealthKitManaging) {
        self.healthKit = healthKit
    }

    // MARK: - Simulator-only logic

    #if targetEnvironment(simulator)

    // MARK: Mock contributions (backed by HealthKitManagerMock via safe cast)

    var hrvScoreContribution: Double {
        get {
            guard let mock = healthKit as? HealthKitManagerMock else { return 0 }
            return mock.hrvScoreContribution
        }
        set {
            guard let mock = healthKit as? HealthKitManagerMock else { return }
            mock.hrvScoreContribution = newValue
        }
    }

    var sleepScoreContribution: Double {
        get {
            guard let mock = healthKit as? HealthKitManagerMock else { return 0 }
            return mock.sleepScoreContribution
        }
        set {
            guard let mock = healthKit as? HealthKitManagerMock else { return }
            mock.sleepScoreContribution = newValue
        }
    }

    // MARK: Score preview

    var previewScore: Int {
        Int(min(100, max(-100, hrvScoreContribution + sleepScoreContribution)))
    }

    var previewScoreLabel: String {
        switch previewScore {
        case 55...100:    return "En progression forte"
        case 20...54:     return "En progression"
        case -15...19:    return "Stable"
        case -45 ... -16: return "En dérive légère"
        case -70 ... -46: return "En dérive modérée"
        default:          return "En dérive sévère"
        }
    }

    var previewScoreColor: Color {
        switch previewScore {
        case 20...:      return Color.somiaAccent
        case -45 ... -1: return Color.somiaWarn
        default:         return .red
        }
    }

    // MARK: Live labels

    var latestHRVLabel: String {
        // avg89 ≈ 50 ms (deterministic seed — precise enough for display)
        let avg: Double = 50.0
        let c = max(-0.99, min(0.99, hrvScoreContribution / 200.0))
        let n: Double = 89
        let latest = n * avg * (1 + c) / (n - c)
        return String(format: "≈ %.0f ms", max(15, min(120, latest)))
    }

    var sleepHoursLabel: String {
        let h = max(2.0, min(12.0, 7.5 + sleepScoreContribution / 12.5))
        return String(format: "≈ %.1f h", h)
    }

    // MARK: Contribution formatting

    func contributionLabel(_ pts: Double) -> String {
        let v = Int(pts)
        switch pts {
        case ..<(-30): return "\(v) pts  Dérive forte"
        case ..<(-10): return "\(v) pts  Dérive"
        case 10...:    return "+\(v) pts  \(pts > 30 ? "Progression forte" : "Progression")"
        default:       return "\(v) pts  Stable"
        }
    }

    func contributionColor(_ pts: Double) -> Color {
        if pts < -10 { return Color.somiaWarn }
        if pts > 10  { return Color.somiaAccent }
        return Color.somiaBodyText
    }

    // MARK: Actions

    func applyMockData() async {
        await healthKit.fetchData()
    }

    #endif
}
