import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class HealthCondition {
    var name: String = ""
    var bodyRegion: String?
    var severity: String?
    var notes: String?
    var diagnosedDate: Date?
    var isActive: Bool = true
    var createdAt: Date = Date()

    init() {}
}
