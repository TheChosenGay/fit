import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class WorkoutExercise {
    var exerciseName: String = ""
    var targetBodyRegion: String = ""
    var setsCompleted: Int = 0
    var repsPerSetJSON: String = "[]"
    var formScoresJSON: String = "[]"
    var coachingTipsJSON: String = "[]"
    var averageFormScore: Double = 0

    var repsPerSet: [Int] {
        get { (try? JSONDecoder().decode([Int].self, from: Data(repsPerSetJSON.utf8))) ?? [] }
        set { repsPerSetJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var formScores: [Double] {
        get { (try? JSONDecoder().decode([Double].self, from: Data(formScoresJSON.utf8))) ?? [] }
        set { formScoresJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var coachingTipsReceived: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(coachingTipsJSON.utf8))) ?? [] }
        set { coachingTipsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    init() {}
}
