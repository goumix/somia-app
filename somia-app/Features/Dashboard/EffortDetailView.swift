//
//  EffortDetailView.swift
//  somia-app
//
//  Created by Nathéo Brault on 10/04/2026.
//

import SwiftUI
import HealthKit

// MARK: - ViewModel

@Observable
private final class EffortViewModel {

    let healthKit: any HealthKitManaging
    private let msUnit  = HKUnit.secondUnit(with: .milli)

    var exerciseMinutes: Double? = nil
    var activeCalories: Double?  = nil
    var stepCount: Double?       = nil
    var peakHeartRate: Double?   = nil

    init(healthKit: any HealthKitManaging) {
        self.healthKit = healthKit
    }

    // MARK: - Métriques (direct HKHealthStore)

    func loadMetrics(for date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let exerciseType = HKQuantityType(.appleExerciseTime)
        let energyType   = HKQuantityType(.activeEnergyBurned)
        let stepsType    = HKQuantityType(.stepCount)
        let hrType       = HKQuantityType(.heartRate)

        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        let pred  = HKQuery.predicateForSamples(withStart: start, end: end)

        async let ex    = fetchQuantity(type: exerciseType, predicate: pred)
        async let kcal  = fetchQuantity(type: energyType, predicate: pred)
        async let steps = fetchQuantity(type: stepsType, predicate: pred)
        async let hr    = fetchQuantity(type: hrType, predicate: pred)
        let (exSamples, kcalSamples, stepSamples, hrSamples) = await (ex, kcal, steps, hr)

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        exerciseMinutes = exSamples.isEmpty ? nil :
            exSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .minute()) }
        activeCalories = kcalSamples.isEmpty ? nil :
            kcalSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
        stepCount = stepSamples.isEmpty ? nil :
            stepSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .count()) }
        peakHeartRate = hrSamples.isEmpty ? nil :
            hrSamples.map { $0.quantity.doubleValue(for: bpmUnit) }.max()
    }

    private func fetchQuantity(type: HKQuantityType, predicate: NSPredicate) async -> [HKQuantitySample] {
        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )
        return (try? await descriptor.result(for: HKHealthStore())) ?? []
    }
}

// MARK: - View

struct EffortDetailView: View {

    let qualityScore: Int?

    @Environment(\.healthKit) private var healthKit
    @State private var vm: EffortViewModel?
    @State private var selectedDate: Date = .init()
    @State private var showDatePicker = false

    private var progress: Double  { qualityScore.map { Double($0) / 100.0 } ?? 0.0 }
    private var ringColor: Color  { qualityScore.map { Color.scoreColor(for: Double($0)) } ?? .somiaBodyText }

    private var exerciseDisplay: String {
        guard let vm, let min = vm.exerciseMinutes else { return "--" }
        return "\(Int(min)) min"
    }

    private var caloriesDisplay: String {
        guard let vm, let kcal = vm.activeCalories else { return "--" }
        return "\(Int(kcal)) kcal"
    }

    private var stepsDisplay: String {
        guard let vm, let steps = vm.stepCount else { return "--" }
        return "\(Int(steps))"
    }

    private var peakHRDisplay: String {
        guard let vm, let hr = vm.peakHeartRate else { return "--" }
        return "\(Int(hr)) bpm"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                datePicker
                scoreRing
                HStack(spacing: 12) {
                    metricCard(label: "Durée de l'exercice", value: exerciseDisplay)
                    metricCard(label: "Calories brûlées",    value: caloriesDisplay)
                }
                metricCard(label: "FC maximale du jour", value: peakHRDisplay)
                metricCard(label: "Compteur de pas",     value: stepsDisplay)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.somiaBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Effort")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .onAppear { vm = vm ?? EffortViewModel(healthKit: healthKit) }
        .task(id: selectedDate) { await vm?.loadMetrics(for: selectedDate) }
    }

    // MARK: - Subviews

    private var datePicker: some View {
        Button { showDatePicker.toggle() } label: {
            HStack(spacing: 6) {
                Text(selectedDate.formatted(.dateTime.day().month(.wide).year()))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .presentationDetents([.medium])
                .tint(Color.somiaAccent)
        }
    }

    private var scoreRing: some View {
        let size: CGFloat = 200
        let lw:   CGFloat = 20
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lw)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.7), value: progress)
                .shadow(color: ringColor.opacity(0.4), radius: 12)
            Text(qualityScore.map { "\($0)" } ?? "--")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .padding(.vertical, 8)
    }

    private func metricCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
