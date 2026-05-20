import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class DailyHealthData {
    @Attribute(.unique) var date: Date

    // MARK: - Activity
    var steps: Int = 0
    var activeEnergyKcal: Double = 0
    var basalEnergyKcal: Double?
    var exerciseMinutes: Int = 0
    var standMinutes: Int = 0
    var distanceWalkedKm: Double?
    var flightsClimbed: Int = 0

    // MARK: - Heart Rate
    var heartRateAvg: Double?
    var heartRateMin: Double?
    var heartRateMax: Double?
    var restingHeartRate: Double?
    var heartRateVariability: Double?   // HRV (SDNN), recovery indicator
    var walkingHeartRateAvg: Double?

    // MARK: - Sleep
    var sleepHours: Double?
    var sleepStartTime: Date?
    var sleepEndTime: Date?
    var deepSleepHours: Double?
    var remSleepHours: Double?
    var coreSleepHours: Double?
    var sleepInterruptions: Int = 0

    // MARK: - Other
    var respiratoryRateAvg: Double?
    var bloodOxygenAvg: Double?

    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
    }
}
