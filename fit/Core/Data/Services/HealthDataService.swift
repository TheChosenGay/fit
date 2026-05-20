import Foundation
import SwiftData


@available(iOS 17.0, *)
protocol HealthDataService {
    func fetchDailyHealth(for date: Date, context: ModelContext) throws -> DailyHealthData?
    func saveHealthData(_ data: HealthKitDayData, context: ModelContext) throws
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

    func saveHealthData(_ data: HealthKitDayData, context: ModelContext) throws {
        let dayStart = Calendar.current.startOfDay(for: data.date)
        var descriptor = FetchDescriptor<DailyHealthData>()
        descriptor.predicate = #Predicate { $0.date == dayStart }
        let record: DailyHealthData
        if let existing = try context.fetch(descriptor).first {
            record = existing
        } else {
            record = DailyHealthData(date: data.date)
            context.insert(record)
        }

        // Activity
        record.steps = data.steps
        record.activeEnergyKcal = data.activeEnergyKcal
        record.basalEnergyKcal = data.basalEnergyKcal
        record.exerciseMinutes = data.exerciseMinutes
        record.standMinutes = data.standMinutes
        record.distanceWalkedKm = data.distanceWalkedKm
        record.flightsClimbed = data.flightsClimbed

        // Heart Rate
        record.heartRateAvg = data.heartRateAvg
        record.heartRateMin = data.heartRateMin
        record.heartRateMax = data.heartRateMax
        record.restingHeartRate = data.restingHeartRate
        record.heartRateVariability = data.heartRateVariability
        record.walkingHeartRateAvg = data.walkingHeartRateAvg

        // Sleep
        record.sleepHours = data.sleepHours
        record.sleepStartTime = data.sleepStartTime
        record.sleepEndTime = data.sleepEndTime
        record.deepSleepHours = data.deepSleepHours
        record.remSleepHours = data.remSleepHours
        record.coreSleepHours = data.coreSleepHours
        record.sleepInterruptions = data.sleepInterruptions

        // Other
        record.respiratoryRateAvg = data.respiratoryRateAvg
        record.bloodOxygenAvg = data.bloodOxygenAvg

        record.updatedAt = Date()

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
