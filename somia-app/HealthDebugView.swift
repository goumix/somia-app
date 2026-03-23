import SwiftUI
import HealthKit
import Charts

struct HealthDebugView: View {

    #if targetEnvironment(simulator)
    @State private var hk: any HealthKitManaging = HealthKitManagerMock()
    #else
    @State private var hk: any HealthKitManaging = HealthKitManager.shared
    #endif

    @State private var viewMode: ViewMode = .table

    private enum ViewMode: String, CaseIterable {
        case table  = "Tableau"
        case charts = "Graphique"
    }

    // MARK: - Units

    private let msUnit      = HKUnit.secondUnit(with: .milli)
    private let bpmUnit     = HKUnit.count().unitDivided(by: .minute())
    private let percentUnit = HKUnit.percent()
    private let countUnit   = HKUnit.count()
    private let vo2Unit     = HKUnit(from: "ml/kg*min")
    private let celsiusUnit = HKUnit.degreeCelsius()
    private let minuteUnit  = HKUnit.minute()

    // MARK: - Data — HRV (30 days)

    private var hrvPoints: [(date: Date, value: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return hk.hrvSamples
            .filter { $0.startDate >= cutoff }
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: msUnit)) }
            .sorted { $0.date < $1.date }
    }

    private var hrvAvg: Double {
        guard !hrvPoints.isEmpty else { return 0 }
        return hrvPoints.map(\.value).reduce(0, +) / Double(hrvPoints.count)
    }
    private var hrvMin: Double { hrvPoints.map(\.value).min() ?? 0 }
    private var hrvMax: Double { hrvPoints.map(\.value).max() ?? 0 }

    // MARK: - Data — Sleep (30 nights)

    private var sleepNights: [(date: Date, hours: Double)] {
        let cutoff   = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let calendar = Calendar.current
        let sleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        var byNight: [Date: Double] = [:]
        for s in hk.sleepSamples where sleepValues.contains(s.value) && s.startDate >= cutoff {
            let night = calendar.startOfDay(for: s.startDate)
            byNight[night, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 3600
        }
        return byNight.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    private var sleepAvg: Double {
        guard !sleepNights.isEmpty else { return 0 }
        return sleepNights.map(\.hours).reduce(0, +) / Double(sleepNights.count)
    }
    private var sleepBadNights: Int { sleepNights.filter { $0.hours < 6 }.count }
    private var sleepBest:      Double { sleepNights.map(\.hours).max() ?? 0 }

    // MARK: - Data — Tier 1

    private var rhrPoints: [(date: Date, value: Double)] {
        hk.restingHeartRateSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: bpmUnit)) }
            .sorted { $0.date < $1.date }
    }
    private var rhrAvg: Double { pointsAvg(rhrPoints) }
    private var rhrMin: Double { rhrPoints.map(\.value).min() ?? 0 }
    private var rhrMax: Double { rhrPoints.map(\.value).max() ?? 0 }

    // SpO2 stored as fraction (0.97 = 97 %) — multiplied ×100 for display
    private var spo2Points: [(date: Date, value: Double)] {
        hk.spo2Samples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: percentUnit) * 100) }
            .sorted { $0.date < $1.date }
    }
    private var spo2Avg: Double { pointsAvg(spo2Points) }
    private var spo2Min: Double { spo2Points.map(\.value).min() ?? 0 }
    private var spo2Max: Double { spo2Points.map(\.value).max() ?? 0 }

    private var respRatePoints: [(date: Date, value: Double)] {
        hk.respiratoryRateSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: bpmUnit)) }
            .sorted { $0.date < $1.date }
    }
    private var respRateAvg: Double { pointsAvg(respRatePoints) }
    private var respRateMin: Double { respRatePoints.map(\.value).min() ?? 0 }
    private var respRateMax: Double { respRatePoints.map(\.value).max() ?? 0 }

    // Steps aggregated per day (device may produce multiple samples/day)
    private var stepDays: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for s in hk.stepSamples {
            let day = calendar.startOfDay(for: s.startDate)
            byDay[day, default: 0] += s.quantity.doubleValue(for: countUnit)
        }
        return byDay.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    private var stepAvg: Double { pointsAvg(stepDays) }
    private var stepMin: Double { stepDays.map(\.value).min() ?? 0 }
    private var stepMax: Double { stepDays.map(\.value).max() ?? 0 }

    private var vo2Points: [(date: Date, value: Double)] {
        hk.vo2MaxSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: vo2Unit)) }
            .sorted { $0.date < $1.date }
    }
    private var vo2Avg: Double { pointsAvg(vo2Points) }
    private var vo2Min: Double { vo2Points.map(\.value).min() ?? 0 }
    private var vo2Max: Double { vo2Points.map(\.value).max() ?? 0 }

    // MARK: - Data — Tier 2

    // Wrist temp is a deviation in °C from nightly baseline; values centered around 0
    private var wristTempPoints: [(date: Date, value: Double)] {
        hk.wristTemperatureSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: celsiusUnit)) }
            .sorted { $0.date < $1.date }
    }
    private var wristTempAvg: Double { pointsAvg(wristTempPoints) }
    private var wristTempMin: Double { wristTempPoints.map(\.value).min() ?? 0 }
    private var wristTempMax: Double { wristTempPoints.map(\.value).max() ?? 0 }

    // Daylight aggregated per day
    private var daylightDays: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for s in hk.timeInDaylightSamples {
            let day = calendar.startOfDay(for: s.startDate)
            byDay[day, default: 0] += s.quantity.doubleValue(for: minuteUnit)
        }
        return byDay.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    private var daylightAvg: Double { pointsAvg(daylightDays) }
    private var daylightMin: Double { daylightDays.map(\.value).min() ?? 0 }
    private var daylightMax: Double { daylightDays.map(\.value).max() ?? 0 }

    private var walkingHRPoints: [(date: Date, value: Double)] {
        hk.walkingHeartRateSamples
            .map { (date: $0.startDate, value: $0.quantity.doubleValue(for: bpmUnit)) }
            .sorted { $0.date < $1.date }
    }
    private var walkingHRAvg: Double { pointsAvg(walkingHRPoints) }
    private var walkingHRMin: Double { walkingHRPoints.map(\.value).min() ?? 0 }
    private var walkingHRMax: Double { walkingHRPoints.map(\.value).max() ?? 0 }

    // MARK: - Body

    var body: some View {
        ZStack {
                Color.somiaBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if hk.isLoading {
                        Spacer()
                        ProgressView().tint(Color.somiaAccent)
                        Spacer()
                    } else {
                        Group {
                            if viewMode == .table {
                                tableView
                            } else {
                                chartsScrollView
                            }
                        }
                        .animation(.easeInOut, value: viewMode)
                    }
                }
            }
            .navigationTitle("Debug HealthKit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Actualiser") {
                        Task { await hk.fetchData() }
                    }
                    .foregroundStyle(Color.somiaAccent)
                }
            }
            .task { await hk.fetchData() }
    }

    // MARK: - Vue tableau (inchangée)

    private var tableView: some View {
        List {
            Section("Statut") {
                row("Disponible", hk.isAvailable ? "Oui" : "Non")
                row("Autorisation", hk.authorizationStatus)
                if let err = hk.error {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }

            Section("VFC nocturne — \(hk.hrvSamples.count) échantillon(s)") {
                ForEach(hk.hrvSamples, id: \.uuid) { sample in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f ms", sample.quantity.doubleValue(for: msUnit)))
                            .foregroundStyle(.white)
                        Text(sample.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Color.somiaBodyText)
                    }
                }
            }

            Section("Sommeil — \(hk.sleepSamples.count) échantillon(s)") {
                ForEach(hk.sleepSamples, id: \.uuid) { sample in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sleepLabel(sample.value)).foregroundStyle(.white)
                        Text(
                            "\(sample.startDate.formatted(date: .abbreviated, time: .shortened)) → \(sample.endDate.formatted(date: .omitted, time: .shortened))"
                        )
                        .font(.caption)
                        .foregroundStyle(Color.somiaBodyText)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Vue graphiques

    private var chartsScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Existing cards — always shown
                hrvChartCard
                sleepChartCard
                // Tier 1 — hidden when data unavailable on this device
                if !hk.restingHeartRateSamples.isEmpty { rhrChartCard }
                if !hk.spo2Samples.isEmpty             { spo2ChartCard }
                if !hk.respiratoryRateSamples.isEmpty  { respRateChartCard }
                if !hk.stepSamples.isEmpty             { stepsChartCard }
                if !hk.vo2MaxSamples.isEmpty           { vo2MaxChartCard }
                // Tier 2 — hidden when data unavailable on this device
                if !hk.wristTemperatureSamples.isEmpty { wristTempChartCard }
                if !hk.timeInDaylightSamples.isEmpty   { daylightChartCard }
                if !hk.walkingHeartRateSamples.isEmpty { walkingHRChartCard }
            }
            .padding(16)
        }
    }

    // MARK: - HRV chart card

    private var hrvChartCard: some View {
        chartCard {
            chartHeader(title: "VFC nocturne", subtitle: "30 derniers jours")

            Chart {
                ForEach(hrvPoints, id: \.date) { p in
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("VFC", p.value)
                    )
                    .foregroundStyle(accentGreen.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                }
                ForEach(hrvPoints, id: \.date) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("VFC", p.value)
                    )
                    .foregroundStyle(accentGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                if hrvAvg > 0 {
                    RuleMark(y: .value("Moyenne", hrvAvg))
                        .foregroundStyle(accentGreen.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.0f ms", hrvAvg))
                                .font(.caption2)
                                .foregroundStyle(accentGreen)
                        }
                }
            }
            .chartXScale(domain: last30Days)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text("\(Int(n)) ms").font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", String(format: "%.0f ms", hrvAvg)),
                ("Min",     String(format: "%.0f ms", hrvMin)),
                ("Max",     String(format: "%.0f ms", hrvMax))
            )
        }
    }

    // MARK: - Sleep chart card

    private var sleepChartCard: some View {
        chartCard {
            chartHeader(title: "Durée de sommeil", subtitle: "30 derniers jours")

            Chart {
                ForEach(sleepNights, id: \.date) { n in
                    BarMark(
                        x: .value("Date", n.date, unit: .day),
                        y: .value("Heures", n.hours)
                    )
                    .foregroundStyle(colorForSleep(n.hours))
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Recommandé", 7.0))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 3) {
                        Text("7 h recommandées")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
            }
            .chartXScale(domain: last30Days)
            .chartYScale(domain: 0...10)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 2, 4, 6, 7, 8, 10]) { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text("\(Int(n)) h").font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne",    String(format: "%.1f h", sleepAvg)),
                ("Nuits < 6 h", "\(sleepBadNights)"),
                ("Meilleure",  String(format: "%.1f h", sleepBest))
            )
        }
    }

    // MARK: - Resting Heart Rate chart card

    private var rhrChartCard: some View {
        chartCard {
            chartHeader(title: "FC au repos", subtitle: "30 derniers jours · bpm")

            Chart {
                ForEach(rhrPoints, id: \.date) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("BPM", p.value))
                        .foregroundStyle(accentOrange.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(rhrPoints, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("BPM", p.value))
                        .foregroundStyle(accentOrange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if rhrAvg > 0 {
                    RuleMark(y: .value("Moyenne", rhrAvg))
                        .foregroundStyle(accentOrange.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.0f bpm", rhrAvg))
                                .font(.caption2).foregroundStyle(accentOrange)
                        }
                }
            }
            .chartXScale(domain: last30Days)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text("\(Int(n))").font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", String(format: "%.0f bpm", rhrAvg)),
                ("Min",     String(format: "%.0f bpm", rhrMin)),
                ("Max",     String(format: "%.0f bpm", rhrMax))
            )
        }
    }

    // MARK: - SpO2 chart card

    private var spo2ChartCard: some View {
        chartCard {
            chartHeader(title: "Saturation en O₂ (SpO₂)", subtitle: "30 derniers jours · %")

            Chart {
                ForEach(spo2Points, id: \.date) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("SpO₂", p.value))
                        .foregroundStyle(accentBlue.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(spo2Points, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("SpO₂", p.value))
                        .foregroundStyle(accentBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if spo2Avg > 0 {
                    RuleMark(y: .value("Moyenne", spo2Avg))
                        .foregroundStyle(accentBlue.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.1f %%", spo2Avg))
                                .font(.caption2).foregroundStyle(accentBlue)
                        }
                }
            }
            .chartXScale(domain: last30Days)
            .chartYScale(domain: 90...100) // narrow range — variation is small
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks(values: [90, 92, 94, 96, 98, 100]) { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text("\(Int(n)) %").font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", String(format: "%.1f %%", spo2Avg)),
                ("Min",     String(format: "%.1f %%", spo2Min)),
                ("Max",     String(format: "%.1f %%", spo2Max))
            )
        }
    }

    // MARK: - Respiratory Rate chart card

    private var respRateChartCard: some View {
        chartCard {
            chartHeader(title: "Fréquence respiratoire", subtitle: "30 derniers jours · rpm")

            Chart {
                ForEach(respRatePoints, id: \.date) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("rpm", p.value))
                        .foregroundStyle(accentCyan.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(respRatePoints, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("rpm", p.value))
                        .foregroundStyle(accentCyan)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if respRateAvg > 0 {
                    RuleMark(y: .value("Moyenne", respRateAvg))
                        .foregroundStyle(accentCyan.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.0f rpm", respRateAvg))
                                .font(.caption2).foregroundStyle(accentCyan)
                        }
                }
            }
            .chartXScale(domain: last30Days)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text("\(Int(n))").font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", String(format: "%.0f rpm", respRateAvg)),
                ("Min",     String(format: "%.0f rpm", respRateMin)),
                ("Max",     String(format: "%.0f rpm", respRateMax))
            )
        }
    }

    // MARK: - Steps chart card

    private var stepsChartCard: some View {
        chartCard {
            chartHeader(title: "Nombre de pas", subtitle: "30 derniers jours")

            Chart {
                ForEach(stepDays, id: \.date) { d in
                    BarMark(
                        x: .value("Date", d.date, unit: .day),
                        y: .value("Pas", d.value)
                    )
                    .foregroundStyle(colorForSteps(d.value))
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Objectif", 10_000))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 3) {
                        Text("10 000 pas")
                            .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
            }
            .chartXScale(domain: last30Days)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text(stepsLabel(n)).font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", stepsLabel(stepAvg)),
                ("Min",     stepsLabel(stepMin)),
                ("Max",     stepsLabel(stepMax))
            )
        }
    }

    // MARK: - VO2max chart card

    private var vo2MaxChartCard: some View {
        chartCard {
            chartHeader(title: "VO₂max", subtitle: "90 derniers jours · ml/kg/min")

            Chart {
                ForEach(vo2Points, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("VO₂max", p.value))
                        .foregroundStyle(accentPurple)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                // Point marks highlight sparse weekly measurements
                ForEach(vo2Points, id: \.date) { p in
                    PointMark(x: .value("Date", p.date), y: .value("VO₂max", p.value))
                        .foregroundStyle(accentPurple)
                        .symbolSize(35)
                }
                if vo2Avg > 0 {
                    RuleMark(y: .value("Moyenne", vo2Avg))
                        .foregroundStyle(accentPurple.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.1f", vo2Avg))
                                .font(.caption2).foregroundStyle(accentPurple)
                        }
                }
            }
            .chartXScale(domain: last90Days)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 14)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text(String(format: "%.0f", n)).font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", String(format: "%.1f ml/kg/min", vo2Avg)),
                ("Min",     String(format: "%.1f",           vo2Min)),
                ("Max",     String(format: "%.1f",           vo2Max))
            )
        }
    }

    // MARK: - Wrist Temperature chart card

    private var wristTempChartCard: some View {
        chartCard {
            chartHeader(title: "Température poignet (nuit)", subtitle: "Déviation vs baseline · 30 jours")

            Chart {
                // Neutral zero baseline
                RuleMark(y: .value("Baseline", 0.0))
                    .foregroundStyle(.white.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                ForEach(wristTempPoints, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("°C", p.value))
                        .foregroundStyle(accentWarm)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(wristTempPoints, id: \.date) { p in
                    PointMark(x: .value("Date", p.date), y: .value("°C", p.value))
                        .foregroundStyle(p.value >= 0 ? accentWarm : accentBlue)
                        .symbolSize(20)
                }
            }
            .chartXScale(domain: last30Days)
            .chartYScale(domain: -0.6...0.6)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks(values: [-0.6, -0.3, 0.0, 0.3, 0.6]) { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text(String(format: "%+.1f °C", n)).font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", String(format: "%+.2f °C", wristTempAvg)),
                ("Min",     String(format: "%+.2f °C", wristTempMin)),
                ("Max",     String(format: "%+.2f °C", wristTempMax))
            )
        }
    }

    // MARK: - Time in Daylight chart card

    private var daylightChartCard: some View {
        chartCard {
            chartHeader(title: "Temps en lumière du jour", subtitle: "30 derniers jours · min")

            Chart {
                ForEach(daylightDays, id: \.date) { d in
                    BarMark(
                        x: .value("Date", d.date, unit: .day),
                        y: .value("Min", d.value)
                    )
                    .foregroundStyle(colorForDaylight(d.value))
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Recommandé", 30.0))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 3) {
                        Text("30 min recommandées")
                            .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
            }
            .chartXScale(domain: last30Days)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text("\(Int(n)) min").font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", String(format: "%.0f min", daylightAvg)),
                ("Min",     String(format: "%.0f min", daylightMin)),
                ("Max",     String(format: "%.0f min", daylightMax))
            )
        }
    }

    // MARK: - Walking HR chart card

    private var walkingHRChartCard: some View {
        chartCard {
            chartHeader(title: "FC moyenne à la marche", subtitle: "30 derniers jours · bpm")

            Chart {
                ForEach(walkingHRPoints, id: \.date) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("BPM", p.value))
                        .foregroundStyle(accentCoral.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(walkingHRPoints, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("BPM", p.value))
                        .foregroundStyle(accentCoral)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if walkingHRAvg > 0 {
                    RuleMark(y: .value("Moyenne", walkingHRAvg))
                        .foregroundStyle(accentCoral.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.0f bpm", walkingHRAvg))
                                .font(.caption2).foregroundStyle(accentCoral)
                        }
                }
            }
            .chartXScale(domain: last30Days)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(axisColor)
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine().foregroundStyle(gridColor)
                    AxisTick().foregroundStyle(axisColor)
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text("\(Int(n))").font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", String(format: "%.0f bpm", walkingHRAvg)),
                ("Min",     String(format: "%.0f bpm", walkingHRMin)),
                ("Max",     String(format: "%.0f bpm", walkingHRMax))
            )
        }
    }

    // MARK: - Shared components

    @ViewBuilder
    private func chartCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .background(Color.somiaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.somiaCardBorder, lineWidth: 1)
        )
    }

    private func chartHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.somiaBodyText)
        }
    }

    private func statsRow(
        _ s1: (String, String),
        _ s2: (String, String),
        _ s3: (String, String)
    ) -> some View {
        HStack(spacing: 0) {
            statCell(label: s1.0, value: s1.1)
            Rectangle().fill(Color.somiaCardBorder).frame(width: 1, height: 36)
            statCell(label: s2.0, value: s2.1)
            Rectangle().fill(Color.somiaCardBorder).frame(width: 1, height: 36)
            statCell(label: s3.0, value: s3.1)
        }
        .padding(.vertical, 10)
        .background(Color.somiaBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.somiaBodyText)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.somiaBodyText)
            Spacer()
            Text(value).foregroundStyle(.white)
        }
    }

    private func sleepLabel(_ value: Int) -> String {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed:             return "Au lit"
        case .asleepUnspecified: return "Endormi (non spécifié)"
        case .awake:             return "Éveillé"
        case .asleepCore:        return "Sommeil léger"
        case .asleepDeep:        return "Sommeil profond"
        case .asleepREM:         return "Sommeil REM"
        default:                 return "Inconnu (\(value))"
        }
    }

    // MARK: - Helpers

    private func pointsAvg(_ points: [(date: Date, value: Double)]) -> Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    /// "8 500" below 10 k, "10 k" above — keeps y-axis labels short
    private func stepsLabel(_ v: Double) -> String {
        v >= 10_000 ? String(format: "%.0f k", v / 1_000) : "\(Int(v))"
    }

    // MARK: - Visual constants

    private var accentGreen:  Color { Color(red: 0,     green: 0.784, blue: 0.588) } // #00C896
    private var accentOrange: Color { Color(red: 1.0,   green: 0.584, blue: 0.0)   } // #FF9500
    private var accentBlue:   Color { Color(red: 0.196, green: 0.596, blue: 1.0)   } // #3298FF
    private var accentCyan:   Color { Color(red: 0.196, green: 0.831, blue: 0.922) } // #32D4EB
    private var accentPurple: Color { Color(red: 0.686, green: 0.322, blue: 0.871) } // #AF52DE
    private var accentWarm:   Color { Color(red: 1.0,   green: 0.694, blue: 0.286) } // #FFB149
    private var accentCoral:  Color { Color(red: 1.0,   green: 0.341, blue: 0.471) } // #FF5778
    private var accentYellow: Color { Color(red: 1.0,   green: 0.8,   blue: 0.0)   } // #FFCC00
    private var gridColor:    Color { Color.somiaCardBorder.opacity(0.6) }
    private var axisColor:    Color { Color.somiaBodyText }

    private var last30Days: ClosedRange<Date> {
        let now = Date()
        return (Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now)...now
    }

    private var last90Days: ClosedRange<Date> {
        let now = Date()
        return (Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now)...now
    }

    private func colorForSleep(_ hours: Double) -> Color {
        if hours < 6 { return Color(red: 1, green: 0.267, blue: 0.267) } // #FF4444
        if hours < 7 { return Color(red: 1, green: 0.584, blue: 0)     } // #FF9500
        return accentGreen                                                 // #00C896
    }

    private func colorForSteps(_ steps: Double) -> Color {
        if steps < 5_000  { return Color(red: 1, green: 0.267, blue: 0.267) } // < 5 k  → red
        if steps < 10_000 { return accentOrange                              } // 5–10 k → orange
        return accentGreen                                                      // ≥ 10 k → green
    }

    private func colorForDaylight(_ minutes: Double) -> Color {
        minutes < 30 ? accentOrange : accentYellow // < 30 min → orange · ≥ 30 min → yellow
    }
}
