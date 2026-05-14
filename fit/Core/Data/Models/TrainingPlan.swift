import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class TrainingPlan {
    var name: String = ""
    var descriptionText: String = ""
    var targetGoal: String = ""
    var durationWeeks: Int = 0
    var sessionsPerWeek: Int = 0
    var createdAt: Date = Date()
    var isActive: Bool = false
    @Relationship(deleteRule: .cascade) var sessions: [PlannedSession]? = []

    init() {}
}
