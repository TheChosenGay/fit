import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class WorkoutSession {
    var date: Date = Date()
    var durationSeconds: Int = 0
    var totalReps: Int = 0
    var averageFormScore: Double?
    var caloriesBurned: Double?
    @Relationship(deleteRule: .cascade) var exercises: [WorkoutExercise]? = []
    var notes: String?

    init() {}
}
