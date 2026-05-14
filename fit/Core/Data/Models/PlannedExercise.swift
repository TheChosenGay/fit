import Foundation

struct PlannedExercise: Codable, Equatable {
    var name: String
    var sets: Int
    var repsPerSet: Int
    var restSeconds: Int
    var targetBodyRegion: String
    var coachingCues: [String]
}
