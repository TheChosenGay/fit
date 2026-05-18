import Foundation

// MARK: - NetworkError
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(Error)
    case serverError(Int)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .noData: return "无响应数据"
        case .decodingFailed(let e): return "解析失败: \(e.localizedDescription)"
        case .serverError(let code): return "服务器错误: \(code)"
        case .unknown(let e): return e.localizedDescription
        }
    }
}


enum Method: String {
    case post = "POST"
    case get = "GET"
    case delete = "DELETE"
}

enum EndPoint {
    // assosiative enum type
    case deepseek
    case minimax
    case zhipu
    case claude
    case openai
    case test(userId:String, name:String)
    
    
    var urlString: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/v1/chat/completions"
        case .minimax: return "https://api.minimax.chat/v1/text/chatcompletion_v2"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .claude: return "https://api.anthropic.com/v1/messages"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .test(let userId, let name): return "https://va1.com/v1/\(userId)/\(name)"
        }
    }
    
    // 业务类型
    var url: URL? {
        return URL(string:urlString)
    }
    
    var method:Method {
        switch self {
        case .deepseek, .minimax, .zhipu, .claude, .openai:
            return .post
        case .test:
            return .get
        }
    
    }
}

// MARK: - NetworkService
final class NetworkService {
    static let shared = NetworkService()
    private init() {}

    func request<T: Decodable>(
        endpoint: EndPoint,
        body: Data? = nil,
        authKey: String? = nil,
    ) async throws -> T {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }
        
        var headers:[String:String] = [:]
        if let key = authKey {
            let headers = ["Authorization": "Bearer \(key)"]
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.httpBody = body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0)}

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
