import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class PoseIssue {
    var name: String = ""
    var severity: String = ""
    var issueDescription: String = ""
    var score: Int = 0

    init() {}
}
