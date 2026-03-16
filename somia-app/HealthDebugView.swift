import SwiftUI
import HealthKit

struct HealthDebugView: View {

    #if targetEnvironment(simulator)
    @State private var hk: any HealthKitManaging = HealthKitManagerMock()
    #else
    @State private var hk: any HealthKitManaging = HealthKitManager.shared
    #endif

    private let msUnit = HKUnit.secondUnit(with: .milli)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somiaBackground.ignoresSafeArea()

                if hk.isLoading {
                    ProgressView()
                        .tint(Color.somiaAccent)
                } else {
                    List {
                        Section("Statut") {
                            row("Disponible", hk.isAvailable ? "Oui" : "Non")
                            row("Autorisation", hk.authorizationStatus)
                            if let err = hk.error {
                                Text(err)
                                    .foregroundStyle(.red)
                                    .font(.caption)
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
                                    Text(sleepLabel(sample.value))
                                        .foregroundStyle(.white)
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
            .task {
                await hk.fetchData()
            }
        }
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
        case .inBed:              return "Au lit"
        case .asleepUnspecified:  return "Endormi (non spécifié)"
        case .awake:              return "Éveillé"
        case .asleepCore:         return "Sommeil léger"
        case .asleepDeep:         return "Sommeil profond"
        case .asleepREM:          return "Sommeil REM"
        default:                  return "Inconnu (\(value))"
        }
    }
}
