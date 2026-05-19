import Foundation

// MARK: - Coach event types

enum CoachEvent {
    case poseDeviation(joint: String, current: Float, standard: Float, feedback: String)
    case phaseChange(from: String, to: String)
    case repComplete(count: Int, score: Int)
    case userSpeech(text: String)
    case formScore(score: Int, feedback: String)

    var priority: Int {
        switch self {
        case .userSpeech: return 100
        case .poseDeviation: return 80
        case .formScore: return 60
        case .repComplete: return 40
        case .phaseChange: return 20
        }
    }

    var description: String {
        switch self {
        case .poseDeviation(let joint, let current, let standard, let feedback):
            return "动作偏差：\(joint)角度\(String(format: "%.0f", current))°（标准\(String(format: "%.0f", standard))°）- \(feedback)"
        case .phaseChange(let from, let to):
            return "动作阶段变化：\(from) → \(to)"
        case .repComplete(let count, let score):
            return "完成第\(count)次动作，评分\(score)分"
        case .userSpeech(let text):
            return "用户说：\(text)"
        case .formScore(let score, let feedback):
            return "当前动作评分：\(score)分 - \(feedback)"
        }
    }

    var isUrgent: Bool {
        switch self {
        case .userSpeech: return true
        case .poseDeviation: return true
        case .formScore(let score, _): return score < 60
        default: return false
        }
    }
}
