import Foundation

// MARK: - Coach context (prompt assembly)

struct CoachContext {
    let systemPrompt: String
    let userContext: String
}

// MARK: - Daily briefing

struct CoachBriefing: Codable {
    let greeting: String
    let healthSummary: String
    let todayAdvice: String
    let motivationQuote: String

    enum CodingKeys: String, CodingKey {
        case greeting
        case healthSummary = "health_summary"
        case todayAdvice = "today_advice"
        case motivationQuote = "motivation_quote"
    }
}

// MARK: - Weekly report

struct CoachReport: Codable {
    let summary: String
    let improvements: [String]
    let recommendations: [String]
}

// MARK: - Pre-workout advice

struct WorkoutAdvice: Codable {
    let shouldTrain: Bool
    let reason: String
    let suggestedFocus: String?
    let warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case shouldTrain = "should_train"
        case reason
        case suggestedFocus = "suggested_focus"
        case warnings
    }
}
