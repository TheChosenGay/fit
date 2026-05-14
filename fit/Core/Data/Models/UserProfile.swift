import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class UserProfile {
    var name: String = ""
    var dateOfBirth: Date?
    var biologicalSex: String?
    var heightCm: Double?
    var weightKg: Double?
    var fitnessGoal: String?
    var activityLevel: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade) var healthConditions: [HealthCondition]? = []
    @Relationship(deleteRule: .cascade) var weightHistory: [WeightRecord]? = []
    @Relationship(deleteRule: .cascade) var trainingPlans: [TrainingPlan]? = []

    init() {}
}
