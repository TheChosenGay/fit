import Foundation

struct AnalysisReport: Codable {
    struct Issue: Codable, Identifiable {
        var id: String { name }
        let name: String
        let severity: String
        let description: String
        let score: Int

        enum CodingKeys: String, CodingKey {
            case name, severity, description, score
        }
    }

    let issues: [Issue]
    let overallScore: Int
    let summary: String

    enum CodingKeys: String, CodingKey {
        case issues
        case overallScore = "overall_score"
        case summary
    }
}
