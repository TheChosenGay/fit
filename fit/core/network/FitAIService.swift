//
//  FitAIService.swift
//  fit
//
//  Created by dai shan on 2026/5/18.
//

import Foundation

enum AIServiceError: Error {
    case emptyResponse
}

struct FitAIRequest: Encodable {
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

struct FitAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

protocol FitAIService {
    func query(req: FitAIRequest) async throws -> String
}

