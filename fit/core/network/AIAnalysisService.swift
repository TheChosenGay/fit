import Foundation

final class AIAnalysisService: PoseAnalysisService {
    nonisolated static let shared = AIAnalysisService()
    private let aiService = FitGenericAIService(type: .deepseek)
    private init() {}

    func analyze(angles: PoseAngle) async throws -> AnalysisReport {
        let request = buildRequest(angles: angles)
        let text = try await aiService.query(req: request)
        let jsonText = stripMarkdownCodeBlock(text)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIAnalysisError.invalidJSON
        }

        return try JSONDecoder().decode(AnalysisReport.self, from: jsonData)
    }

    private func buildRequest(angles: PoseAngle) -> FitAIRequest {
        let prompt = """
        你是一位专业的体态评估师。根据以下正面照检测数据（基于身体中轴线的相对测量），给出体态分析报告。只分析有数据支撑的问题，数据正常项可简要提及。

        检测数据：
        - 头部侧倾角：\(formatAngle(angles.headForward))（两耳连线与水平的夹角，正常 ≤3°，轻度 3-7°，明显 >7°）
        - 高低肩差：\(formatPixel(angles.shoulderDiff))（两肩沿身体垂直方向的高度差，正常 ≤30px，轻度 30-60px，明显 >60px）
        - 肩部倾斜角：\(formatAngle(angles.roundShoulder))（两肩连线与水平的夹角，正常 ≤3°，轻度 3-7°，明显 >7°）
        - 骨盆倾斜角：\(formatAngle(angles.pelvicTilt))（两髋连线与水平的夹角，正常 ≤3°，轻度 3-7°，明显 >7°）
        - 腿型偏移：\(formatPixel(angles.legAlignment))（膝偏离髋踝连线的距离，正常 ≤25px，轻度 25-45px，明显 >45px）

        注意：以上数据来自正面照，无法评估侧面体态问题（如头前伸、圆肩、骨盆前倾）。请仅根据正面可观测的指标给出分析。

        请返回严格 JSON（不要 markdown 代码块标记），issues 只包含异常项：
        {"issues":[{"name":"高低肩","severity":"moderate","description":"右肩明显高于左肩...","score":65}],"overall_score":72,"summary":"一句话总结"}
        """

        return FitAIRequest(
            model: "deepseek-chat",
            maxTokens: 1024,
            messages: [
                .init(role: "system", content: "你是一位专业的体态评估师。用中文回答，给出3-5个主要问题，严格返回JSON格式。"),
                .init(role: "user", content: prompt),
            ]
        )
    }

    private func formatAngle(_ value: Float?) -> String {
        value.map { String(format: "%.1f°", $0) } ?? "无数据"
    }

    private func formatDiff(_ value: Float?) -> String {
        value.map { String(format: "%.3f", $0) } ?? "无数据"
    }

    private func formatPixel(_ value: Float?) -> String {
        value.map { String(format: "%.0f px", $0) } ?? "无数据"
    }

    private func stripMarkdownCodeBlock(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
        }
        if t.hasSuffix("```") {
            t = String(t.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }
}

// MARK: - AIAnalysisError

enum AIAnalysisError: Error, LocalizedError {
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .emptyResponse: return "AI 未返回内容"
        case .invalidJSON: return "AI 返回格式异常"
        }
    }
}

// MARK: - DeepSeek API models (OpenAI-compatible)

private struct DeepSeekRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct DeepSeekResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
