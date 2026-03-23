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

    private let msUnit = HKUnit.secondUnit(with: .milli)

    // MARK: - Données VFC (30 derniers jours)

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

    // MARK: - Données sommeil (30 dernières nuits)

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
                hrvChartCard
                sleepChartCard
            }
            .padding(16)
        }
    }

    // MARK: Graphique VFC

    private var hrvChartCard: some View {
        chartCard {
            chartHeader(title: "VFC nocturne", subtitle: "30 derniers jours")

            Chart {
                // Remplissage sous la courbe
                ForEach(hrvPoints, id: \.date) { p in
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("VFC", p.value)
                    )
                    .foregroundStyle(accentGreen.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                }
                // Courbe principale
                ForEach(hrvPoints, id: \.date) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("VFC", p.value)
                    )
                    .foregroundStyle(accentGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                // Ligne de base (moyenne 30 j)
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

    // MARK: Graphique sommeil

    private var sleepChartCard: some View {
        chartCard {
            chartHeader(title: "Durée de sommeil", subtitle: "30 derniers jours")

            Chart {
                // Barres colorées selon durée
                ForEach(sleepNights, id: \.date) { n in
                    BarMark(
                        x: .value("Date", n.date, unit: .day),
                        y: .value("Heures", n.hours)
                    )
                    .foregroundStyle(colorForSleep(n.hours))
                    .cornerRadius(3)
                }
                // Seuil recommandé 7 h
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

    // MARK: - Composants partagés

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

    // MARK: - Constantes visuelles

    private var accentGreen: Color { Color(red: 0,   green: 0.784, blue: 0.588) } // #00C896
    private var gridColor:   Color { Color.somiaCardBorder.opacity(0.6) }
    private var axisColor:   Color { Color.somiaBodyText }

    private var last30Days: ClosedRange<Date> {
        let now = Date()
        return (Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now)...now
    }

    private func colorForSleep(_ hours: Double) -> Color {
        if hours < 6 { return Color(red: 1, green: 0.267, blue: 0.267) } // #FF4444
        if hours < 7 { return Color(red: 1, green: 0.584, blue: 0)     } // #FF9500
        return accentGreen                                                 // #00C896
    }
}
