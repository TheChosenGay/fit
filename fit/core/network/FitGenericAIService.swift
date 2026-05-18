//
//  FitDeepseekAIService.swift
//  fit
//
//  Created by dai shan on 2026/5/18.
//

import Foundation

enum AIServiceType {
    case deepseek
    case minimax
    case zhipu
    case claude
}

struct FitGenericAIService: FitAIService {
    let type: AIServiceType
    func query(req: FitAIRequest) async throws -> String {
        let body = try JSONEncoder().encode(req)
        let response: FitAIResponse = try await NetworkService.shared.request(
            endpoint: endpoint,
            body: body,
            authKey: authKey
        )

        guard let text = response.choices.first?.message.content else {
            throw AIServiceError.emptyResponse
        }
        return text
    }
    
    var endpoint: EndPoint {
        switch type {
        case .deepseek: return .deepseek
        case .minimax: return .minimax
        case .zhipu: return .zhipu
        case .claude: return .claude
        }
    }
    
    var authKey: String {
        switch type {
        case .deepseek: return Secrets.deepseekAPIKey
        default:
            return Secrets.minimaxAPIKey
        }
    }
}
