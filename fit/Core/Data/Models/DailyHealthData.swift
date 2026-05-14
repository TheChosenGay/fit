import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class DailyHealthData {
    @Attribute(.unique) var date: Date
    var steps: Int = 0
    var activeEnergyKcal: Double = 0
    var heartRateAvg: Double?
    var heartRateMin: Double?
    var heartRateMax: Double?
    var sleepHours: Double?
    var sleepQuality: String?
    var restingHeartRate: Double?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
    }
}
