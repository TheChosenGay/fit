import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class PlannedSession {
    var dayOfWeek: Int = 1
    var focusArea: String = ""
    var warmupMinutes: Int = 5
    var cooldownMinutes: Int = 5
    var exercisesJSON: String = "[]"

    var exercises: [PlannedExercise] {
        get { (try? JSONDecoder().decode([PlannedExercise].self, from: Data(exercisesJSON.utf8))) ?? [] }
        set { exercisesJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    init() {}
}
