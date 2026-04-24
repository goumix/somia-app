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
    @Environment(\.healthKit) private var healthKit

    // MARK: - State

    @AppStorage("userName") private var userName: String = "Alex"
    @State private var vm: SettingsViewModel?
    @State private var showEditName = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somiaBackground.ignoresSafeArea()

                List {
                    profileHeaderSection

                    #if targetEnvironment(simulator)
                    if let vm { mockDataSection(vm: vm) }
                    #endif

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
        .sheet(isPresented: $showEditName) {
            EditNameSheet(userName: $userName)
        }
        .task {
            if vm == nil {
                vm = SettingsViewModel(healthKit: healthKit)
            }
        }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
        Section {
            Button { showEditName = true } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(userName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Text("Modifier le prénom")
                            .font(.subheadline)
                            .foregroundStyle(Color.somiaBodyText)
                    }

                    Spacer()

                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(Color.somiaBodyText)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.somiaCard)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        Section {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Paramètres généraux", systemImage: "gearshape")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.somiaCard)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Permissions HealthKit", systemImage: "heart.text.clipboard")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.somiaCard)
        } header: {
            sectionHeader("PARAMÈTRES")
        }
    }

    // MARK: - Share Section

    private var shareSection: some View {
        Section {
            Button {
                if let url = URL(string: "https://www.reddit.com/r/somiahealth/") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Reddit", systemImage: "bubble.left.and.bubble.right")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.somiaCard)

            Button {
                if let url = URL(string: "https://www.linkedin.com/company/getsomia/about/") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("LinkedIn", systemImage: "person.2")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.somiaCard)
        } header: {
            sectionHeader("S'IMPLIQUER")
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

    private func mockDataSection(vm: SettingsViewModel) -> some View {
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
            profilesGrid(vm: vm)
                .listRowBackground(Color.somiaCard)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // ── Sliders de contribution ────────────────────────────────────
            contributionRow(
                label: "HRV",
                subtitle: vm.latestHRVLabel,
                vm: vm,
                value: bindable.hrvScoreContribution
            )
            contributionRow(
                label: "Sommeil",
                subtitle: vm.sleepHoursLabel,
                vm: vm,
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

    private func profilesGrid(vm: SettingsViewModel) -> some View {
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

    private func contributionRow(
        label: String,
        subtitle: String,
        vm: SettingsViewModel,
        value: Binding<Double>
    ) -> some View {
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

// MARK: - EditNameSheet

private struct EditNameSheet: View {
    @Binding var userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somiaBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    TextField("Prénom", text: $draft)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.somiaCard)
                        .clipShape(RoundedRectangle(cornerRadius: SomiaRadius.md))
                        .padding(.horizontal, SomiaSpacing.md)
                    Spacer()
                }
                .padding(.top, SomiaSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Color.somiaBodyText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        let trimmed = draft.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { userName = trimmed }
                        dismiss()
                    }
                    .foregroundStyle(Color.somiaAccent)
                    .fontWeight(.semibold)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
        .onAppear { draft = userName }
    }
}

// MARK: - Preview

#Preview("iPhone") {
    #if targetEnvironment(simulator)
    SettingsView()
        .environment(\.healthKit, HealthKitManagerMock())
    #else
    SettingsView()
    #endif
}

#Preview("iPad Air M3") {
    #if targetEnvironment(simulator)
    SettingsView()
        .environment(\.healthKit, HealthKitManagerMock())
    #else
    SettingsView()
    #endif
}
