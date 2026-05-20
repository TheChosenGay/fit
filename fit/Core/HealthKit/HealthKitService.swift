import Foundation
import HealthKit

// MARK: - Day data struct

struct HealthKitDayData {
    let date: Date

    // Activity
    let steps: Int
    let activeEnergyKcal: Double
    let basalEnergyKcal: Double?
    let exerciseMinutes: Int
    let standMinutes: Int
    let distanceWalkedKm: Double?
    let flightsClimbed: Int

    // Heart Rate
    let heartRateAvg: Double?
    let heartRateMin: Double?
    let heartRateMax: Double?
    let restingHeartRate: Double?
    let heartRateVariability: Double?
    let walkingHeartRateAvg: Double?

    // Sleep
    let sleepHours: Double?
    let sleepStartTime: Date?
    let sleepEndTime: Date?
    let deepSleepHours: Double?
    let remSleepHours: Double?
    let coreSleepHours: Double?
    let sleepInterruptions: Int

    // Other
    let respiratoryRateAvg: Double?
    let bloodOxygenAvg: Double?
}

// MARK: - Protocol

protocol HealthKitService {
    func requestAuthorization() async throws -> Bool
    func fetchDailyData(for date: Date) async throws -> HealthKitDayData
    func fetchDataRange(from start: Date, to end: Date) async throws -> [HealthKitDayData]
    func enableBackgroundDelivery() async throws
}

// MARK: - Implementation

@MainActor
final class HKHealthKitService: HealthKitService {
    static let shared = HKHealthKitService()

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        ]
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        return types
    }

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws -> Bool {
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        ]
        return try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: success) }
            }
        }
    }

    // MARK: - Daily data (parallel fetch)

    func fetchDailyData(for date: Date) async throws -> HealthKitDayData {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        async let steps = fetchSteps(from: dayStart, to: dayEnd)
        async let activeEnergy = fetchActiveEnergy(from: dayStart, to: dayEnd)
        async let basalEnergy = fetchBasalEnergy(from: dayStart, to: dayEnd)
        async let exerciseMin = fetchExerciseMinutes(from: dayStart, to: dayEnd)
        async let standMin = fetchStandMinutes(from: dayStart, to: dayEnd)
        async let distance = fetchDistanceWalked(from: dayStart, to: dayEnd)
        async let flights = fetchFlightsClimbed(from: dayStart, to: dayEnd)
        async let hrStats = fetchHeartRateStats(from: dayStart, to: dayEnd)
        async let restingHR = fetchRestingHeartRate()
        async let hrv = fetchHeartRateVariability()
        async let walkingHR = fetchWalkingHeartRate()
        async let sleepDetail = fetchSleepDetail(from: dayStart, to: dayEnd)
        async let respiratory = fetchRespiratoryRate(from: dayStart, to: dayEnd)
        async let bloodO2 = fetchBloodOxygen(from: dayStart, to: dayEnd)

        return HealthKitDayData(
            date: dayStart,
            steps: (try? await steps) ?? 0,
            activeEnergyKcal: (try? await activeEnergy) ?? 0,
            basalEnergyKcal: try? await basalEnergy,
            exerciseMinutes: (try? await exerciseMin) ?? 0,
            standMinutes: (try? await standMin) ?? 0,
            distanceWalkedKm: try? await distance,
            flightsClimbed: (try? await flights) ?? 0,
            heartRateAvg: try? await hrStats.avg,
            heartRateMin: try? await hrStats.min,
            heartRateMax: try? await hrStats.max,
            restingHeartRate: try? await restingHR,
            heartRateVariability: try? await hrv,
            walkingHeartRateAvg: try? await walkingHR,
            sleepHours: try? await sleepDetail.totalHours,
            sleepStartTime: try? await sleepDetail.startTime,
            sleepEndTime: try? await sleepDetail.endTime,
            deepSleepHours: try? await sleepDetail.deepHours,
            remSleepHours: try? await sleepDetail.remHours,
            coreSleepHours: try? await sleepDetail.coreHours,
            sleepInterruptions: (try? await sleepDetail.interruptions) ?? 0,
            respiratoryRateAvg: try? await respiratory,
            bloodOxygenAvg: try? await bloodO2
        )
    }

    func fetchDataRange(from start: Date, to end: Date) async throws -> [HealthKitDayData] {
        var results: [HealthKitDayData] = []
        var current = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)
        while current <= endDay {
            let data = try await fetchDailyData(for: current)
            results.append(data)
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }
        return results
    }

    func enableBackgroundDelivery() async throws {
        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            try await store.enableBackgroundDelivery(for: stepType, frequency: .hourly)
        }
    }

    // MARK: - Activity fetchers

    private func fetchSteps(from start: Date, to end: Date) async throws -> Int {
        Int(try await fetchCumulativeSum(identifier: .stepCount, unit: HKUnit.count(), from: start, to: end))
    }

    private func fetchActiveEnergy(from start: Date, to end: Date) async throws -> Double {
        try await fetchCumulativeSum(identifier: .activeEnergyBurned, unit: HKUnit.kilocalorie(), from: start, to: end)
    }

    private func fetchBasalEnergy(from start: Date, to end: Date) async throws -> Double {
        try await fetchCumulativeSum(identifier: .basalEnergyBurned, unit: HKUnit.kilocalorie(), from: start, to: end)
    }

    private func fetchExerciseMinutes(from start: Date, to end: Date) async throws -> Int {
        Int(try await fetchCumulativeSum(identifier: .appleExerciseTime, unit: HKUnit.minute(), from: start, to: end))
    }

    private func fetchStandMinutes(from start: Date, to end: Date) async throws -> Int {
        Int(try await fetchCumulativeSum(identifier: .appleStandTime, unit: HKUnit.minute(), from: start, to: end))
    }

    private func fetchDistanceWalked(from start: Date, to end: Date) async throws -> Double {
        let meters = try await fetchCumulativeSum(identifier: .distanceWalkingRunning, unit: HKUnit.meter(), from: start, to: end)
        return meters / 1000.0
    }

    private func fetchFlightsClimbed(from start: Date, to end: Date) async throws -> Int {
        Int(try await fetchCumulativeSum(identifier: .flightsClimbed, unit: HKUnit.count(), from: start, to: end))
    }

    // MARK: - Heart Rate fetchers

    private struct HeartRateStats {
        let avg: Double?
        let min: Double?
        let max: Double?
        static let empty = HeartRateStats(avg: nil, min: nil, max: nil)
    }

    private func fetchHeartRateStats(from start: Date, to end: Date) async throws -> HeartRateStats {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return .empty }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error = error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        guard !samples.isEmpty else { return .empty }

        let bpmValues = samples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
        return HeartRateStats(
            avg: bpmValues.reduce(0, +) / Double(bpmValues.count),
            min: bpmValues.min(),
            max: bpmValues.max()
        )
    }

    private func fetchRestingHeartRate() async throws -> Double {
        try await fetchLatestSample(identifier: .restingHeartRate, unit: HKUnit(from: "count/min"))
    }

    private func fetchHeartRateVariability() async throws -> Double {
        try await fetchLatestSample(identifier: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
    }

    private func fetchWalkingHeartRate() async throws -> Double {
        try await fetchLatestSample(identifier: .walkingHeartRateAverage, unit: HKUnit(from: "count/min"))
    }

    // MARK: - Sleep detail

    private struct SleepDetail {
        let totalHours: Double?
        let startTime: Date?
        let endTime: Date?
        let deepHours: Double?
        let remHours: Double?
        let coreHours: Double?
        let interruptions: Int

        static let empty = SleepDetail(
            totalHours: nil, startTime: nil, endTime: nil,
            deepHours: nil, remHours: nil, coreHours: nil, interruptions: 0
        )
    }

    private func fetchSleepDetail(from start: Date, to end: Date) async throws -> SleepDetail {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return .empty }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, results, error in
                if let error = error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        guard !samples.isEmpty else { return .empty }

        var deepSeconds: Double = 0
        var remSeconds: Double = 0
        var coreSeconds: Double = 0
        var asleepSeconds: Double = 0
        var interruptions = 0
        var lastAsleepEnd: Date?
        let sleepStart = samples.first?.startDate
        let sleepEnd = samples.last?.endDate

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)

            // Count interruptions: gap between consecutive asleep samples
            if sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                if let lastEnd = lastAsleepEnd {
                    let gap = sample.startDate.timeIntervalSince(lastEnd)
                    if gap > 300 { interruptions += 1 } // >5min gap = interruption
                }
                lastAsleepEnd = sample.endDate
            }

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                 HKCategoryValueSleepAnalysis.asleepDeep.rawValue...HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                // asUnspecified goes to core as fallback
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                    coreSeconds += duration
                }
                asleepSeconds += duration
            default:
                break
            }
        }

        return SleepDetail(
            totalHours: asleepSeconds > 0 ? asleepSeconds / 3600.0 : nil,
            startTime: sleepStart,
            endTime: sleepEnd,
            deepHours: deepSeconds > 0 ? deepSeconds / 3600.0 : nil,
            remHours: remSeconds > 0 ? remSeconds / 3600.0 : nil,
            coreHours: coreSeconds > 0 ? coreSeconds / 3600.0 : nil,
            interruptions: interruptions
        )
    }

    // MARK: - Other vitals

    private func fetchRespiratoryRate(from start: Date, to end: Date) async throws -> Double {
        try await fetchAverage(identifier: .respiratoryRate, unit: HKUnit(from: "count/min"), from: start, to: end)
    }

    private func fetchBloodOxygen(from start: Date, to end: Date) async throws -> Double {
        try await fetchAverage(identifier: .oxygenSaturation, unit: HKUnit.percent(), from: start, to: end) * 100
    }

    // MARK: - Generic helpers

    private func fetchCumulativeSum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchLatestSample(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func fetchAverage(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = stats?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
