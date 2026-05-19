import UIKit

// MARK: - Protocol

protocol DietAnalysisService {
    func analyze(image: UIImage) async throws -> MealAnalysisResult
}

// MARK: - Result types

struct MealAnalysisResult: Codable {
    let foodItems: [String]
    let itemBreakdown: [ItemNutrition]?
    let totalCalories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let description: String

    enum CodingKeys: String, CodingKey {
        case foodItems = "food_items"
        case itemBreakdown = "item_breakdown"
        case totalCalories = "total_calories"
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case description
    }
}

struct ItemNutrition: Codable {
    let name: String
    let ingredients: [String]
    let estimatedGrams: Int
    let kcalPer100g: Double

    enum CodingKeys: String, CodingKey {
        case name, ingredients
        case estimatedGrams = "estimated_grams"
        case kcalPer100g = "kcal_per100g"
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
                    .text("你是一位专业的营养师。根据食物照片，识别每种食物并估算营养成分。用中文回答，严格返回JSON格式。注意区分盘中不同菜品，每种菜品列出主要食材。")
                ]),
                .init(role: "user", content: [
                    .text("""
                    请识别这张照片中的所有食物，逐一分析每种食物的营养成分。

                    返回严格JSON（不要markdown代码块标记）：
                    {
                      "food_items": ["宫保鸡丁", "米饭"],
                      "item_breakdown": [
                        {"name": "宫保鸡丁", "ingredients": ["鸡肉", "花生", "辣椒"], "estimated_grams": 280, "kcal_per100g": 190},
                        {"name": "米饭", "ingredients": ["大米"], "estimated_grams": 200, "kcal_per100g": 116}
                      ],
                      "total_calories": 764,
                      "protein_grams": 35.0,
                      "carbs_grams": 80.0,
                      "fat_grams": 28.0,
                      "description": "一份宫保鸡丁配米饭，荤素搭配均衡"
                    }
                    """),
                    .imageUrl(.init(url: "data:image/jpeg;base64,\(base64)"))
                ])
            ]
        )

        let encoded = try JSONEncoder().encode(body)
        let response: DietMultimodalResponse = try await NetworkService.shared.request(
            endpoint: .zhipu,
            body: encoded,
            authKey: Secrets.zhipuAPIKey
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

// MARK: - MiniMax implementation

final class MiniMaxDietAnalysisService: DietAnalysisService {
    nonisolated static let shared = MiniMaxDietAnalysisService()
    private init() {}

    func analyze(image: UIImage) async throws -> MealAnalysisResult {
        let base64 = image.jpegData(compressionQuality: 0.7)?.base64EncodedString() ?? ""

        let body = DietMultimodalRequest(
            model: "MiniMax-M2.7",
            maxTokens: 1024,
            messages: [
                .init(role: "system", content: [
                    .text("你是一位专业的营养师。根据食物照片，识别每种食物并估算营养成分。用中文回答，严格返回JSON格式。注意区分盘中不同菜品，每种菜品列出主要食材。")
                ]),
                .init(role: "user", content: [
                    .text("""
                    请识别这张照片中的所有食物，逐一分析每种食物的营养成分。

                    返回严格JSON（不要markdown代码块标记）：
                    {
                      "food_items": ["宫保鸡丁", "米饭"],
                      "item_breakdown": [
                        {"name": "宫保鸡丁", "ingredients": ["鸡肉", "花生", "辣椒"], "estimated_grams": 280, "kcal_per100g": 190},
                        {"name": "米饭", "ingredients": ["大米"], "estimated_grams": 200, "kcal_per100g": 116}
                      ],
                      "total_calories": 764,
                      "protein_grams": 35.0,
                      "carbs_grams": 80.0,
                      "fat_grams": 28.0,
                      "description": "一份宫保鸡丁配米饭，荤素搭配均衡"
                    }
                    """),
                    .imageUrl(.init(url: "data:image/jpeg;base64,\(base64)"))
                ])
            ]
        )

        let encoded = try JSONEncoder().encode(body)
        let response: DietMultimodalResponse = try await NetworkService.shared.request(
            endpoint: .minimax,
            body: encoded,
            authKey: Secrets.minimaxAPIKey
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
