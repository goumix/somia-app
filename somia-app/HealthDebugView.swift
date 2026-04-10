import SwiftUI
import HealthKit
import Charts

struct HealthDebugView: View {

    // MARK: - ViewModel

    #if targetEnvironment(simulator)
    @State private var vm = HealthDebugViewModel(healthKit: HealthKitManagerMock())
    #else
    @State private var vm = HealthDebugViewModel()
    #endif

    @State private var viewMode: ViewMode = .table

    private enum ViewMode: String, CaseIterable {
        case table  = "Tableau"
        case charts = "Graphique"
    }

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

                    if vm.isLoading {
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
                        Task { await vm.fetchData() }
                    }
                    .foregroundStyle(Color.somiaAccent)
                }
            }
            .task { await vm.fetchData() }
    }

    // MARK: - Vue tableau (inchangée)

    private var tableView: some View {
        List {
            Section("Statut") {
                row("Disponible", vm.isAvailable ? "Oui" : "Non")
                row("Autorisation", vm.authorizationStatus)
                if let err = vm.error {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }

            Section("VFC nocturne — \(vm.hrvSamples.count) échantillon(s)") {
                ForEach(vm.hrvSamples, id: \.uuid) { sample in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.formattedHRVSample(sample))
                            .foregroundStyle(.white)
                        Text(sample.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Color.somiaBodyText)
                    }
                }
            }

            Section("Sommeil — \(vm.sleepSamples.count) échantillon(s)") {
                ForEach(vm.sleepSamples, id: \.uuid) { sample in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.sleepLabel(sample.value)).foregroundStyle(.white)
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
                if !vm.rhrPoints.isEmpty       { rhrChartCard }
                if !vm.spo2Points.isEmpty      { spo2ChartCard }
                if !vm.respRatePoints.isEmpty  { respRateChartCard }
                if !vm.stepDays.isEmpty        { stepsChartCard }
                if !vm.vo2Points.isEmpty       { vo2MaxChartCard }
                // Tier 2 — hidden when data unavailable on this device
                if !vm.wristTempPoints.isEmpty { wristTempChartCard }
                if !vm.daylightDays.isEmpty    { daylightChartCard }
                if !vm.walkingHRPoints.isEmpty { walkingHRChartCard }
            }
            .padding(16)
        }
    }

    // MARK: - HRV chart card

    private var hrvChartCard: some View {
        chartCard {
            chartHeader(title: "VFC nocturne", subtitle: "30 derniers jours")

            Chart {
                ForEach(vm.hrvPoints, id: \.date) { p in
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("VFC", p.value)
                    )
                    .foregroundStyle(accentGreen.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                }
                ForEach(vm.hrvPoints, id: \.date) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("VFC", p.value)
                    )
                    .foregroundStyle(accentGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                if vm.hrvAvg > 0 {
                    RuleMark(y: .value("Moyenne", vm.hrvAvg))
                        .foregroundStyle(accentGreen.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.0f ms", vm.hrvAvg))
                                .font(.caption2)
                                .foregroundStyle(accentGreen)
                        }
                }
            }
            .chartXScale(domain: vm.last30Days)
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
                ("Moyenne", String(format: "%.0f ms", vm.hrvAvg)),
                ("Min",     String(format: "%.0f ms", vm.hrvMin)),
                ("Max",     String(format: "%.0f ms", vm.hrvMax))
            )
        }
    }

    // MARK: - Sleep chart card

    private var sleepChartCard: some View {
        chartCard {
            chartHeader(title: "Durée de sommeil", subtitle: "30 derniers jours")

            Chart {
                ForEach(vm.sleepNights, id: \.date) { n in
                    BarMark(
                        x: .value("Date", n.date, unit: .day),
                        y: .value("Heures", n.hours)
                    )
                    .foregroundStyle(vm.colorForSleep(n.hours))
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
            .chartXScale(domain: vm.last30Days)
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
                ("Moyenne",    String(format: "%.1f h", vm.sleepAvg)),
                ("Nuits < 6 h", "\(vm.sleepBadNights)"),
                ("Meilleure",  String(format: "%.1f h", vm.sleepBest))
            )
        }
    }

    // MARK: - Resting Heart Rate chart card

    private var rhrChartCard: some View {
        chartCard {
            chartHeader(title: "FC au repos", subtitle: "30 derniers jours · bpm")

            Chart {
                ForEach(vm.rhrPoints, id: \.date) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("BPM", p.value))
                        .foregroundStyle(accentOrange.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(vm.rhrPoints, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("BPM", p.value))
                        .foregroundStyle(accentOrange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if vm.rhrAvg > 0 {
                    RuleMark(y: .value("Moyenne", vm.rhrAvg))
                        .foregroundStyle(accentOrange.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.0f bpm", vm.rhrAvg))
                                .font(.caption2).foregroundStyle(accentOrange)
                        }
                }
            }
            .chartXScale(domain: vm.last30Days)
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
                ("Moyenne", String(format: "%.0f bpm", vm.rhrAvg)),
                ("Min",     String(format: "%.0f bpm", vm.rhrMin)),
                ("Max",     String(format: "%.0f bpm", vm.rhrMax))
            )
        }
    }

    // MARK: - SpO2 chart card

    private var spo2ChartCard: some View {
        chartCard {
            chartHeader(title: "Saturation en O₂ (SpO₂)", subtitle: "30 derniers jours · %")

            Chart {
                ForEach(vm.spo2Points, id: \.date) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("SpO₂", p.value))
                        .foregroundStyle(accentBlue.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(vm.spo2Points, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("SpO₂", p.value))
                        .foregroundStyle(accentBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if vm.spo2Avg > 0 {
                    RuleMark(y: .value("Moyenne", vm.spo2Avg))
                        .foregroundStyle(accentBlue.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.1f %%", vm.spo2Avg))
                                .font(.caption2).foregroundStyle(accentBlue)
                        }
                }
            }
            .chartXScale(domain: vm.last30Days)
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
                ("Moyenne", String(format: "%.1f %%", vm.spo2Avg)),
                ("Min",     String(format: "%.1f %%", vm.spo2Min)),
                ("Max",     String(format: "%.1f %%", vm.spo2Max))
            )
        }
    }

    // MARK: - Respiratory Rate chart card

    private var respRateChartCard: some View {
        chartCard {
            chartHeader(title: "Fréquence respiratoire", subtitle: "30 derniers jours · rpm")

            Chart {
                ForEach(vm.respRatePoints, id: \.date) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("rpm", p.value))
                        .foregroundStyle(accentCyan.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(vm.respRatePoints, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("rpm", p.value))
                        .foregroundStyle(accentCyan)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if vm.respRateAvg > 0 {
                    RuleMark(y: .value("Moyenne", vm.respRateAvg))
                        .foregroundStyle(accentCyan.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.0f rpm", vm.respRateAvg))
                                .font(.caption2).foregroundStyle(accentCyan)
                        }
                }
            }
            .chartXScale(domain: vm.last30Days)
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
                ("Moyenne", String(format: "%.0f rpm", vm.respRateAvg)),
                ("Min",     String(format: "%.0f rpm", vm.respRateMin)),
                ("Max",     String(format: "%.0f rpm", vm.respRateMax))
            )
        }
    }

    // MARK: - Steps chart card

    private var stepsChartCard: some View {
        chartCard {
            chartHeader(title: "Nombre de pas", subtitle: "30 derniers jours")

            Chart {
                ForEach(vm.stepDays, id: \.date) { d in
                    BarMark(
                        x: .value("Date", d.date, unit: .day),
                        y: .value("Pas", d.value)
                    )
                    .foregroundStyle(vm.colorForSteps(d.value))
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
            .chartXScale(domain: vm.last30Days)
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
                            Text(vm.stepsLabel(n)).font(.caption2).foregroundStyle(axisColor)
                        }
                    }
                }
            }
            .frame(height: 200)

            statsRow(
                ("Moyenne", vm.stepsLabel(vm.stepAvg)),
                ("Min",     vm.stepsLabel(vm.stepMin)),
                ("Max",     vm.stepsLabel(vm.stepMax))
            )
        }
    }

    // MARK: - VO2max chart card

    private var vo2MaxChartCard: some View {
        chartCard {
            chartHeader(title: "VO₂max", subtitle: "90 derniers jours · ml/kg/min")

            Chart {
                ForEach(vm.vo2Points, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("VO₂max", p.value))
                        .foregroundStyle(accentPurple)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                // Point marks highlight sparse weekly measurements
                ForEach(vm.vo2Points, id: \.date) { p in
                    PointMark(x: .value("Date", p.date), y: .value("VO₂max", p.value))
                        .foregroundStyle(accentPurple)
                        .symbolSize(35)
                }
                if vm.vo2Avg > 0 {
                    RuleMark(y: .value("Moyenne", vm.vo2Avg))
                        .foregroundStyle(accentPurple.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.1f", vm.vo2Avg))
                                .font(.caption2).foregroundStyle(accentPurple)
                        }
                }
            }
            .chartXScale(domain: vm.last90Days)
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
                ("Moyenne", String(format: "%.1f ml/kg/min", vm.vo2Avg)),
                ("Min",     String(format: "%.1f",           vm.vo2Min)),
                ("Max",     String(format: "%.1f",           vm.vo2Max))
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

                ForEach(vm.wristTempPoints, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("°C", p.value))
                        .foregroundStyle(accentWarm)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(vm.wristTempPoints, id: \.date) { p in
                    PointMark(x: .value("Date", p.date), y: .value("°C", p.value))
                        .foregroundStyle(p.value >= 0 ? accentWarm : accentBlue)
                        .symbolSize(20)
                }
            }
            .chartXScale(domain: vm.last30Days)
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
                ("Moyenne", String(format: "%+.2f °C", vm.wristTempAvg)),
                ("Min",     String(format: "%+.2f °C", vm.wristTempMin)),
                ("Max",     String(format: "%+.2f °C", vm.wristTempMax))
            )
        }
    }

    // MARK: - Time in Daylight chart card

    private var daylightChartCard: some View {
        chartCard {
            chartHeader(title: "Temps en lumière du jour", subtitle: "30 derniers jours · min")

            Chart {
                ForEach(vm.daylightDays, id: \.date) { d in
                    BarMark(
                        x: .value("Date", d.date, unit: .day),
                        y: .value("Min", d.value)
                    )
                    .foregroundStyle(vm.colorForDaylight(d.value))
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
            .chartXScale(domain: vm.last30Days)
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
                ("Moyenne", String(format: "%.0f min", vm.daylightAvg)),
                ("Min",     String(format: "%.0f min", vm.daylightMin)),
                ("Max",     String(format: "%.0f min", vm.daylightMax))
            )
        }
    }

    // MARK: - Walking HR chart card

    private var walkingHRChartCard: some View {
        chartCard {
            chartHeader(title: "FC moyenne à la marche", subtitle: "30 derniers jours · bpm")

            Chart {
                ForEach(vm.walkingHRPoints, id: \.date) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("BPM", p.value))
                        .foregroundStyle(accentCoral.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(vm.walkingHRPoints, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("BPM", p.value))
                        .foregroundStyle(accentCoral)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if vm.walkingHRAvg > 0 {
                    RuleMark(y: .value("Moyenne", vm.walkingHRAvg))
                        .foregroundStyle(accentCoral.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 3) {
                            Text(String(format: "Moy. %.0f bpm", vm.walkingHRAvg))
                                .font(.caption2).foregroundStyle(accentCoral)
                        }
                }
            }
            .chartXScale(domain: vm.last30Days)
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
                ("Moyenne", String(format: "%.0f bpm", vm.walkingHRAvg)),
                ("Min",     String(format: "%.0f bpm", vm.walkingHRMin)),
                ("Max",     String(format: "%.0f bpm", vm.walkingHRMax))
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

    // MARK: - Visual constants (UI-only, stay in View)

    private var accentGreen:  Color { Color(red: 0,     green: 0.784, blue: 0.588) } // #00C896
    private var accentOrange: Color { Color(red: 1.0,   green: 0.584, blue: 0.0)   } // #FF9500
    private var accentBlue:   Color { Color(red: 0.196, green: 0.596, blue: 1.0)   } // #3298FF
    private var accentCyan:   Color { Color(red: 0.196, green: 0.831, blue: 0.922) } // #32D4EB
    private var accentPurple: Color { Color(red: 0.686, green: 0.322, blue: 0.871) } // #AF52DE
    private var accentWarm:   Color { Color(red: 1.0,   green: 0.694, blue: 0.286) } // #FFB149
    private var accentCoral:  Color { Color(red: 1.0,   green: 0.341, blue: 0.471) } // #FF5778
    private var gridColor:    Color { Color.somiaCardBorder.opacity(0.6) }
    private var axisColor:    Color { Color.somiaBodyText }
}
