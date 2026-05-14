import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class PoseAnalysisRecord {
    var date: Date = Date()
    var imageFileName: String?
    var headForward: Double?
    var shoulderDiff: Double?
    var roundShoulder: Double?
    var pelvicTilt: Double?
    var legAlignment: Double?
    var viewAngle: String = ""
    var overallScore: Int = 0
    var summary: String = ""
    @Relationship(deleteRule: .cascade) var issues: [PoseIssue]? = []
    var aiModelUsed: String = ""

    init() {}
}
