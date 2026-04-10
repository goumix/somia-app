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

    // MARK: - ViewModel

    #if targetEnvironment(simulator)
    @State private var vm: SettingsViewModel
    init(mock: HealthKitManagerMock) {
        _vm = State(wrappedValue: SettingsViewModel(healthKit: mock))
    }
    #else
    @State private var vm = SettingsViewModel()
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
            Label("Reddit", systemImage: "person.fill")
                .foregroundStyle(.white)
                .listRowBackground(Color.somiaCard)

            Label("Linkedin", systemImage: "person.fill")
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

    // MARK: Mock section

    private var mockDataSection: some View {
        let bindable = Bindable(vm)
        return Section {

            // ── Score preview ──────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Score prévu")
                        .font(.caption)
                        .foregroundStyle(Color.somiaBodyText)
                    Text(vm.previewScoreLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(vm.previewScoreColor)
                }
                Spacer()
                Text(vm.previewScore >= 0 ? "+\(vm.previewScore)" : "\(vm.previewScore)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(vm.previewScoreColor)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.somiaCard)

            // ── Profils prédéfinis ─────────────────────────────────────────
            profilesGrid
                .listRowBackground(Color.somiaCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // ── Sliders de contribution ────────────────────────────────────
            contributionRow(
                label: "HRV",
                subtitle: vm.latestHRVLabel,
                value: bindable.hrvScoreContribution
            )
            contributionRow(
                label: "Sommeil",
                subtitle: vm.sleepHoursLabel,
                value: bindable.sleepScoreContribution
            )

            // ── Bouton Appliquer ───────────────────────────────────────────
            Button {
                Task { await vm.applyMockData() }
            } label: {
                HStack {
                    Spacer()
                    Text("Appliquer")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.somiaAccent)
                    Spacer()
                }
            }
            .listRowBackground(Color.somiaCard)

        } header: {
            sectionHeader("MOCK DATA")
        }
    }

    // Grille 2 colonnes des profils physiologiques
    private var profilesGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("PROFILS")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(PhysioProfile.allCases, id: \.self) { profile in
                    let isSelected = vm.hrvScoreContribution == profile.hrvContrib
                                  && vm.sleepScoreContribution == profile.sleepContrib
                    Button {
                        vm.hrvScoreContribution   = profile.hrvContrib
                        vm.sleepScoreContribution = profile.sleepContrib
                    } label: {
                        VStack(spacing: 2) {
                            Text(profile.label)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(isSelected ? Color.somiaBackground : .white)
                                .multilineTextAlignment(.center)
                            Text(profile.totalScore >= 0 ? "+\(profile.totalScore)" : "\(profile.totalScore)")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? Color.somiaBackground.opacity(0.7) : Color.somiaBodyText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.somiaAccent : Color.somiaCardBorder)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // Slider d'une contribution avec label live (UI helper — reste dans la View)
    private func contributionRow(label: String, subtitle: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.somiaBodyText)
                }
                Spacer()
                Text(vm.contributionLabel(value.wrappedValue))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(vm.contributionColor(value.wrappedValue))
                    .frame(width: 90, alignment: .trailing)
            }

            Slider(value: value, in: -50...50, step: 1)
                .tint(vm.contributionColor(value.wrappedValue))

            HStack {
                Text("−50 pts  dérive")
                    .font(.caption2)
                    .foregroundStyle(Color.somiaBodyText)
                Spacer()
                Text("progression  +50 pts")
                    .font(.caption2)
                    .foregroundStyle(Color.somiaBodyText)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.somiaCard)
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
