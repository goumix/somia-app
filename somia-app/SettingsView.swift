//
//  SettingsView.swift
//  somia-app
//
//  Created by Nathéo Brault on 30/03/2026.
//

import SwiftUI

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @AppStorage("userName") private var userName: String = "Alex"

    // MARK: - Mock (simulator only)

    #if targetEnvironment(simulator)
    let mock: HealthKitManagerMock
    #endif

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somiaBackground.ignoresSafeArea()

                List {
                    profileHeaderSection

                    #if targetEnvironment(simulator)
                    mockDataSection
                    #endif

                    personalizeSection
                    settingsSection
                    shareSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(Color.somiaBodyText)
                    }
                }
            }
        }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.somiaAccent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(userName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text("Voir le profil")
                        .font(.subheadline)
                        .foregroundStyle(Color.somiaBodyText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.somiaBodyText)
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.somiaCard)
        }
    }

    // MARK: - Personalize Section

    private var personalizeSection: some View {
        Section {
            Label("Informations personnelles", systemImage: "person")
                .foregroundStyle(.white)
                .listRowBackground(Color.somiaCard)
        } header: {
            sectionHeader("PERSONNALISER")
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        Section {
            Label("Paramètres généraux", systemImage: "gearshape")
                .foregroundStyle(.white)
                .listRowBackground(Color.somiaCard)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Permissions HealthKit", systemImage: "heart.text.clipboard")
                    .foregroundStyle(.white)
            }
            .listRowBackground(Color.somiaCard)
        } header: {
            sectionHeader("PARAMÈTRES")
        }
    }
    
    // MARK: - Share Section

    private var shareSection: some View {
        Section {
            Label("Instagram", systemImage: "person.fill")
                .foregroundStyle(.white)
                .listRowBackground(Color.somiaCard)

            Label("Reddit", systemImage: "person.fill")
                .foregroundStyle(.white)
                .listRowBackground(Color.somiaCard)
            
            .listRowBackground(Color.somiaCard)
        } header: {
            sectionHeader("S'impliquer")
        }
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.somiaBodyText)
            .tracking(1.2)
    }

    // MARK: - Mock Data Section (Simulator only)

    #if targetEnvironment(simulator)

    private var mockDataSection: some View {
        let bindable = Bindable(mock)
        return Section {
            // Scenario sliders
            scenarioRow(label: "HRV",      value: bindable.hrvScenario)
            scenarioRow(label: "Sommeil",  value: bindable.sleepScenario)
            scenarioRow(label: "FC repos", value: bindable.rhrScenario)
            scenarioRow(label: "SpO2",     value: bindable.spo2Scenario)

            // Apply button
            Button {
                Task { await mock.fetchData() }
            } label: {
                HStack {
                    Spacer()
                    Text("Appliquer les scénarios")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.somiaAccent)
                    Spacer()
                }
            }
            .listRowBackground(Color.somiaCard)

            // Presets grid
            presetsGrid
                .listRowBackground(Color.somiaCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

        } header: {
            sectionHeader("MOCK DATA")
        }
    }

    private func scenarioRow(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Text(scenarioLabel(value.wrappedValue))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(scenarioColor(value.wrappedValue))
            }

            Slider(value: value, in: -1...1, step: 0.5)
                .tint(scenarioColor(value.wrappedValue))

            HStack {
                Text("Dérive")
                    .font(.caption2)
                    .foregroundStyle(Color.somiaBodyText)
                Spacer()
                Text("Progression")
                    .font(.caption2)
                    .foregroundStyle(Color.somiaBodyText)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.somiaCard)
    }

    private var presetsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRESETS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(1.2)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(MockPreset.allCases, id: \.self) { preset in
                    Button {
                        Task { await mock.applyPreset(preset) }
                    } label: {
                        Text(preset.label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.somiaCardBorder)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func scenarioLabel(_ value: Double) -> String {
        switch value {
        case ..<(-0.7): return "Dérive forte"
        case ..<(-0.2): return "Dérive légère"
        case 0.2...:    return value > 0.7 ? "Progression forte" : "Progression"
        default:        return "Stable"
        }
    }

    private func scenarioColor(_ value: Double) -> Color {
        if value < -0.2 { return Color.somiaWarn }
        if value > 0.2  { return Color.somiaAccent }
        return Color.somiaBodyText
    }

    #endif
}

// MARK: - Preview

#Preview {
    #if targetEnvironment(simulator)
    SettingsView(mock: HealthKitManagerMock())
    #else
    SettingsView()
    #endif
}
