import UIKit

protocol MultimodalAnalysisService {
    func analyze(image: UIImage, angles: PoseAngle) async throws -> AnalysisReport
}

// MARK: - Zhipu GLM-4V

final class ZhipuVisionService: MultimodalAnalysisService {
    nonisolated static let shared = ZhipuVisionService()
    private init() {}

    func analyze(image: UIImage, angles: PoseAngle) async throws -> AnalysisReport {
        let imageData = image.jpegData(compressionQuality: 0.7)
        let base64 = imageData?.base64EncodedString() ?? ""

        let prompt = buildPrompt(angles: angles)

        let body = ZhipuRequest(
            model: "glm-4v",
            maxTokens: 1024,
            messages: [
                .init(role: "system", content: [.text("你是一位专业的体态评估师。根据边缘检测图像和测量数据，给出体态分析报告。用中文回答，严格返回JSON格式。")]),
                .init(role: "user", content: [
                    .text(prompt),
                    .imageUrl(.init(url: "data:image/jpeg;base64,\(base64)"))
                ])
            ]
        )

        let headers = [
            "Authorization": "Bearer \(Secrets.zhipuAPIKey)",
        ]

        let encoded = try JSONEncoder().encode(body)
        let response: ZhipuResponse = try await NetworkService.shared.request(
            url: ServiceEndpoint.Zhipu.chatCompletions,
            headers: headers,
            body: encoded
        )

        guard let text = response.choices.first?.message.content else {
            throw AIAnalysisError.emptyResponse
        }

        let jsonText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIAnalysisError.invalidJSON
        }

        return try JSONDecoder().decode(AnalysisReport.self, from: jsonData)
    }

    private func buildPrompt(angles: PoseAngle) -> String {
        """
        根据边缘检测图像（显示身体轮廓和绿色骨骼标注）以及以下测量数据，给出体态分析报告。请结合视觉观察和数据做综合判断，只分析有数据支撑的问题。

        检测数据（相对身体中轴线的测量）：
        - 头部侧倾角：\(fmt(angles.headForward))（正常 ≤3°，轻度 3-7°，明显 >7°）
        - 高低肩差：\(fmtPixel(angles.shoulderDiff))（正常 ≤30px，轻度 30-60px，明显 >60px）
        - 肩部倾斜角：\(fmt(angles.roundShoulder))（正常 ≤3°，轻度 3-7°，明显 >7°）
        - 骨盆倾斜角：\(fmt(angles.pelvicTilt))（正常 ≤3°，轻度 3-7°，明显 >7°）
        - 腿型偏移/膝角度：\(angles.legAlignment.map { String(format: "%.1f", $0) } ?? "无数据")

        请严格返回 JSON（不要 markdown 代码块标记），issues 只包含异常项：
        {"issues":[{"name":"高低肩","severity":"moderate","description":"右肩明显高于左肩...","score":65}],"overall_score":72,"summary":"正面观体态整体对称，存在轻微高低肩..."}
        """
    }

    private func fmt(_ v: Float?) -> String { v.map { String(format: "%.1f°", $0) } ?? "无数据" }
    private func fmtPixel(_ v: Float?) -> String { v.map { String(format: "%.0f px", $0) } ?? "无数据" }
}

// MARK: - Zhipu API models

private struct ZhipuRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: [Content]
    }

    struct Content: Encodable {
        let type: String
        let text: String?
        let imageUrl: ImageUrl?

        struct ImageUrl: Encodable {
            let url: String
        }

        static func text(_ t: String) -> Content {
            Content(type: "text", text: t, imageUrl: nil)
        }

        static func imageUrl(_ i: ImageUrl) -> Content {
            Content(type: "image_url", text: nil, imageUrl: i)
        }

        enum CodingKeys: String, CodingKey {
            case type, text, imageUrl = "image_url"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        }
    }

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct ZhipuResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
