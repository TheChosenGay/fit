import Foundation
import SwiftData


@available(iOS 17.0, *)
protocol HealthDataService {
    func fetchDailyHealth(for date: Date, context: ModelContext) throws -> DailyHealthData?
    func saveDailyHealth(_ data: DailyHealthData, context: ModelContext) throws
    func fetchHealthRange(from start: Date, to end: Date, context: ModelContext) throws -> [DailyHealthData]
}

@available(iOS 17.0, *)
struct DefaultHealthDataService: HealthDataService {
    func fetchDailyHealth(for date: Date, context: ModelContext) throws -> DailyHealthData? {
        let dayStart = Calendar.current.startOfDay(for: date)
        var descriptor = FetchDescriptor<DailyHealthData>()
        descriptor.predicate = #Predicate { $0.date == dayStart }
        return try context.fetch(descriptor).first
    }

    func saveDailyHealth(_ data: DailyHealthData, context: ModelContext) throws {
        let dayStart = Calendar.current.startOfDay(for: data.date)
        var descriptor = FetchDescriptor<DailyHealthData>()
        descriptor.predicate = #Predicate { $0.date == dayStart }
        if let existing = try context.fetch(descriptor).first {
            existing.steps = data.steps
            existing.activeEnergyKcal = data.activeEnergyKcal
            existing.heartRateAvg = data.heartRateAvg
            existing.heartRateMin = data.heartRateMin
            existing.heartRateMax = data.heartRateMax
            existing.sleepHours = data.sleepHours
            existing.sleepQuality = data.sleepQuality
            existing.restingHeartRate = data.restingHeartRate
            existing.updatedAt = Date()
        } else {
            context.insert(data)
        }
        try context.save()
    }

    func fetchHealthRange(from start: Date, to end: Date, context: ModelContext) throws -> [DailyHealthData] {
        let dayStart = Calendar.current.startOfDay(for: start)
        let dayEnd = Calendar.current.startOfDay(for: end)
        var descriptor = FetchDescriptor<DailyHealthData>()
        descriptor.predicate = #Predicate { $0.date >= dayStart && $0.date <= dayEnd }
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]
        return try context.fetch(descriptor)
    }
}
