import Foundation

final class AIAnalysisService: PoseAnalysisService {
    nonisolated static let shared = AIAnalysisService()
    private init() {}

    func analyze(angles: PoseAngle) async throws -> AnalysisReport {
        let body = try JSONEncoder().encode(buildRequest(angles: angles))
        let headers = [
            "Authorization": "Bearer \(Secrets.deepseekAPIKey)",
        ]

        let response: DeepSeekResponse = try await NetworkService.shared.request(
            url: ServiceEndpoint.DeepSeek.chatCompletions,
            headers: headers,
            body: body
        )

        guard let text = response.choices.first?.message.content else {
            throw AIAnalysisError.emptyResponse
        }

        let jsonText = stripMarkdownCodeBlock(text)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIAnalysisError.invalidJSON
        }

        return try JSONDecoder().decode(AnalysisReport.self, from: jsonData)
    }

    private func buildRequest(angles: PoseAngle) -> DeepSeekRequest {
        let prompt = """
        你是一位专业的体态评估师。根据以下检测数据，给出体态分析报告。只分析有数据支撑的问题，数据正常项可简要提及。

        检测数据：
        - 头前伸角度：\(formatAngle(angles.headForward))（正常 ≤5°，轻度 5-10°，明显 >10°）
        - 高低肩差：\(formatDiff(angles.shoulderDiff))（归一化值，正常 ≤0.01，轻度 0.01-0.02，明显 >0.02）
        - 圆肩角度：\(formatAngle(angles.roundShoulder))（正常 ≤10°，轻度 10-15°，明显 >15°）
        - 骨盆前倾角度：\(formatAngle(angles.pelvicTilt))（正常 ≤10°，轻度 10-15°，明显 >15°）
        - 腿型偏移：\(formatDiff(angles.legAlignment))（归一化值，正常 ≤0.02，轻度 0.02-0.03，明显 >0.03）

        请返回严格 JSON（不要 markdown 代码块标记），issues 只包含异常项：
        {"issues":[{"name":"圆肩","severity":"moderate","description":"肩关节前旋明显...","score":65}],"overall_score":72,"summary":"一句话总结"}
        """

        return DeepSeekRequest(
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
