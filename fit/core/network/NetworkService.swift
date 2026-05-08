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

// MARK: - NetworkService
final class NetworkService {
    static let shared = NetworkService()
    private init() {}

    func request<T: Decodable>(
        url: URL,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> T {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }

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
