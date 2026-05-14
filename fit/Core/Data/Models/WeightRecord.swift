import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class WeightRecord {
    var date: Date = Date()
    var weightKg: Double = 0
    var bodyFatPercentage: Double?
    var source: String = "manual"

    init() {}
}
