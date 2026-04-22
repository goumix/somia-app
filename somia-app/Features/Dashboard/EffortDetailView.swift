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
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    var exerciseMinutes: Double? = nil
    var activeCalories: Double?  = nil
    var stepCount: Double?       = nil
    var peakHeartRate: Double?   = nil

    init(healthKit: any HealthKitManaging) {
        self.healthKit = healthKit
    }

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

        let store = HKHealthStore()
        async let ex    = fetchQuantity(type: exerciseType, predicate: pred, store: store)
        async let kcal  = fetchQuantity(type: energyType,   predicate: pred, store: store)
        async let steps = fetchQuantity(type: stepsType,    predicate: pred, store: store)
        async let hr    = fetchQuantity(type: hrType,       predicate: pred, store: store)
        let (exSamples, kcalSamples, stepSamples, hrSamples) = await (ex, kcal, steps, hr)

        exerciseMinutes = exSamples.isEmpty ? nil :
            exSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .minute()) }
        activeCalories = kcalSamples.isEmpty ? nil :
            kcalSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
        stepCount = stepSamples.isEmpty ? nil :
            stepSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .count()) }
        peakHeartRate = hrSamples.isEmpty ? nil :
            hrSamples.map { $0.quantity.doubleValue(for: bpmUnit) }.max()
    }

    private func fetchQuantity(
        type: HKQuantityType,
        predicate: NSPredicate,
        store: HKHealthStore
    ) async -> [HKQuantitySample] {
        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )
        return (try? await descriptor.result(for: store)) ?? []
    }
}

// MARK: - View

struct EffortDetailView: View {

    let scoreResult: EffortScoreCalculator.Result?

    @Environment(\.healthKit) private var healthKit
    @State private var vm: EffortViewModel?
    @State private var selectedDate: Date = .init()
    @State private var showDatePicker = false

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
                ScoreDonutView(data: scoreResult?.donutData(), size: 200)
                    .padding(.vertical, 8)
                HStack(spacing: 12) {
                    MetricCell(label: "Durée de l'exercice", value: exerciseDisplay)
                    MetricCell(label: "Calories brûlées",    value: caloriesDisplay)
                }
                MetricCell(label: "FC maximale du jour", value: peakHRDisplay)
                MetricCell(label: "Compteur de pas",     value: stepsDisplay)
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
}
