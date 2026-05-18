import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class StandardSequenceCatalog {
    var sequenceId: String = ""
    var exerciseId: String = ""
    var exerciseName: String = ""
    var version: Int = 1
    var difficulty: String = "beginner"
    var localFilePath: String = ""
    var isBuiltIn: Bool = false
    var downloadedAt: Date = Date()
    var fileSize: Int = 0
    var lastUsedAt: Date?

    init(
        sequenceId: String,
        exerciseId: String,
        exerciseName: String,
        version: Int = 1,
        difficulty: String = "beginner",
        localFilePath: String,
        isBuiltIn: Bool = false,
        fileSize: Int = 0
    ) {
        self.sequenceId = sequenceId
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.version = version
        self.difficulty = difficulty
        self.localFilePath = localFilePath
        self.isBuiltIn = isBuiltIn
        self.fileSize = fileSize
        self.downloadedAt = Date()
    }
}
