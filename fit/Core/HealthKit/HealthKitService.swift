import Foundation
import HealthKit

struct HealthKitDayData {
    let date: Date
    let steps: Int
    let activeEnergyKcal: Double
    let heartRateAvg: Double?
    let restingHeartRate: Double?
    let sleepHours: Double?
}

protocol HealthKitService {
    func requestAuthorization() async throws -> Bool
    func fetchDailyData(for date: Date) async throws -> HealthKitDayData
    func fetchDataRange(from start: Date, to end: Date) async throws -> [HealthKitDayData]
    func enableBackgroundDelivery() async throws
}

@MainActor
final class HKHealthKitService: HealthKitService {
    static let shared = HKHealthKitService()

    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        ]
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        return types
    }()

    private init() {}

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

    func fetchDailyData(for date: Date) async throws -> HealthKitDayData {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        async let steps = fetchStepCount(from: dayStart, to: dayEnd)
        async let energy = fetchActiveEnergy(from: dayStart, to: dayEnd)
        async let hrAvg = fetchAverageHeartRate(from: dayStart, to: dayEnd)
        async let restingHR = fetchRestingHeartRate()
        async let sleep = fetchSleepHours(from: dayStart, to: dayEnd)

        return HealthKitDayData(
            date: dayStart,
            steps: try await steps,
            activeEnergyKcal: try await energy,
            heartRateAvg: try? await hrAvg,
            restingHeartRate: try? await restingHR,
            sleepHours: try? await sleep
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
        // Enable background delivery for step count
        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            try await store.enableBackgroundDelivery(for: stepType, frequency: .hourly)
        }
    }

    // MARK: - Private fetchers

    private func fetchStepCount(from start: Date, to end: Date) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(value))
            }
            store.execute(query)
        }
    }

    private func fetchActiveEnergy(from start: Date, to end: Date) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchAverageHeartRate(from start: Date, to end: Date) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let error = error { continuation.resume(throwing: error); return }
                let value = stats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchRestingHeartRate() async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
            }
            store.execute(query)
        }
    }

    private func fetchSleepHours(from start: Date, to end: Date) async throws -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                let totalSeconds = samples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            store.execute(query)
        }
    }
}
