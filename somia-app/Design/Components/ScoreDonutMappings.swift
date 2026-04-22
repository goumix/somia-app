import SwiftUI

// MARK: - SleepScoreCalculator.Result → ScoreDonutData

extension SleepScoreCalculator.Result {
    func donutData() -> ScoreDonutData {
        var segments: [ScoreDonutData.Segment] = []
        if interruptionPoints > 0 { segments.append(.init(id: "inter", points: interruptionPoints, color: .somiaGreenSoft)) }
        if durationPoints     > 0 { segments.append(.init(id: "dur",   points: durationPoints,     color: .somiaAccent)) }
        if bedtimePoints      > 0 { segments.append(.init(id: "bed",   points: bedtimePoints,      color: .somiaWarn)) }
        return ScoreDonutData(total: total, label: label, segments: segments)
    }
}

// MARK: - RecoveryScoreCalculator.Result → ScoreDonutData

extension RecoveryScoreCalculator.Result {
    func donutData() -> ScoreDonutData {
        var segments: [ScoreDonutData.Segment] = []
        if hrvPoints   > 0 { segments.append(.init(id: "hrv",   points: hrvPoints,   color: .somiaAccent)) }
        if rhrPoints   > 0 { segments.append(.init(id: "rhr",   points: rhrPoints,   color: .somiaGreenSoft)) }
        if sleepPoints > 0 { segments.append(.init(id: "sleep", points: sleepPoints, color: .somiaWarn)) }
        let minor = spo2Points + respiPoints
        if minor > 0       { segments.append(.init(id: "minor", points: minor,       color: .white.opacity(0.4))) }
        return ScoreDonutData(total: total, label: label, segments: segments)
    }
}

// MARK: - EffortScoreCalculator.Result → ScoreDonutData

extension EffortScoreCalculator.Result {
    func donutData() -> ScoreDonutData {
        var segments: [ScoreDonutData.Segment] = []
        if stepsPoints    > 0 { segments.append(.init(id: "steps",    points: stepsPoints,    color: .somiaAccent)) }
        if exercisePoints > 0 { segments.append(.init(id: "exercise", points: exercisePoints, color: .somiaGreenSoft)) }
        if caloriesPoints > 0 { segments.append(.init(id: "calories", points: caloriesPoints, color: .somiaWarn)) }
        if hrPoints       > 0 { segments.append(.init(id: "hr",       points: hrPoints,       color: .white.opacity(0.4))) }
        return ScoreDonutData(total: total, label: label, segments: segments)
    }
}
