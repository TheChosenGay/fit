import UIKit

// MARK: - Protocol

protocol DietAnalysisService {
    func analyze(image: UIImage) async throws -> MealAnalysisResult
}

// MARK: - Result type

struct MealAnalysisResult: Codable {
    let foodItems: [String]
    let totalCalories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let description: String

    enum CodingKeys: String, CodingKey {
        case foodItems = "food_items"
        case totalCalories = "total_calories"
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case description
    }
}

// MARK: - Zhipu implementation

final class ZhipuDietAnalysisService: DietAnalysisService {
    nonisolated static let shared = ZhipuDietAnalysisService()
    private init() {}

    func analyze(image: UIImage) async throws -> MealAnalysisResult {
        let base64 = image.jpegData(compressionQuality: 0.7)?.base64EncodedString() ?? ""

        let body = DietMultimodalRequest(
            model: "glm-4v",
            maxTokens: 1024,
            messages: [
                .init(role: "system", content: [
                    .text("你是一位专业的营养师。根据食物照片，识别食物种类并估算营养成分。用中文回答，严格返回JSON格式。")
                ]),
                .init(role: "user", content: [
                    .text("""
                    请识别这张照片中的食物，并估算营养成分。

                    返回严格JSON（不要markdown代码块标记）：
                    {"food_items":["食物名1","食物名2"],"total_calories":500,"protein_grams":25.0,"carbs_grams":60.0,"fat_grams":15.0,"description":"简要描述这顿饭"}
                    """),
                    .imageUrl(.init(url: "data:image/jpeg;base64,\(base64)"))
                ])
            ]
        )

        let encoded = try JSONEncoder().encode(body)
        let response: DietMultimodalResponse = try await NetworkService.shared.request(
            url: ServiceEndpoint.Zhipu.chatCompletions,
            headers: ["Authorization": "Bearer \(Secrets.zhipuAPIKey)"],
            body: encoded
        )

        guard let text = response.choices.first?.message.content else {
            throw DietAnalysisError.emptyResponse
        }

        return try parseDietResponse(text)
    }

    private func parseDietResponse(_ text: String) throws -> MealAnalysisResult {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
        }
        if t.hasSuffix("```") {
            t = String(t.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = t.data(using: .utf8) else {
            throw DietAnalysisError.invalidJSON
        }
        return try JSONDecoder().decode(MealAnalysisResult.self, from: data)
    }
}

// MARK: - Error

enum DietAnalysisError: Error, LocalizedError {
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .emptyResponse: return "AI 未返回分析结果"
        case .invalidJSON: return "AI 返回格式异常"
        }
    }
}

// MARK: - API models

private struct DietMultimodalRequest: Encodable {
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

private struct DietMultimodalResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
