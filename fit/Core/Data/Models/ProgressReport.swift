import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class ProgressReport {
    var date: Date = Date()
    var periodStart: Date = Date()
    var periodEnd: Date = Date()
    var type: String = ""
    var overallScoreChange: Double = 0
    var keyImprovementsJSON: String = "[]"
    var areasNeedingWorkJSON: String = "[]"
    var aiGeneratedSummary: String = ""
    var recommendations: String = ""

    var keyImprovements: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(keyImprovementsJSON.utf8))) ?? [] }
        set { keyImprovementsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    var areasNeedingWork: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(areasNeedingWorkJSON.utf8))) ?? [] }
        set { areasNeedingWorkJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]" }
    }

    init() {}
}
