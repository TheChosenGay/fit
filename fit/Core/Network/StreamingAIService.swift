import Foundation

// MARK: - Streaming chat message

struct StreamingChatMessage: Encodable {
    let role: String
    let content: String
}

// MARK: - Protocol

protocol StreamingAIService {
    /// Callback-based: send query, receive tokens via `onToken`, completion via `onComplete`.
    func query(
        messages: [StreamingChatMessage],
        model: String,
        maxTokens: Int,
        onToken: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    )

    /// Cancel the current streaming request.
    func cancel()
}

extension StreamingAIService {
    /// Stream-based convenience wrapper around `query`.
    func streamChat(
        messages: [StreamingChatMessage],
        model: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            query(
                messages: messages,
                model: model,
                maxTokens: maxTokens,
                onToken: { token in
                    continuation.yield(token)
                },
                onComplete: { error in
                    if let error {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            )
        }
    }
}

// MARK: - HTTP SSE implementation (DeepSeek)

final class HTTPStreamingService: StreamingAIService {
    private let endpoint: URL
    private let apiKey: String
    private var currentTask: Task<Void, Never>?

    init(endpoint: URL, apiKey: String) {
        self.endpoint = endpoint
        self.apiKey = apiKey
    }

    convenience init(deepSeekKey: String) {
        self.init(
            endpoint: URL(string: "https://api.deepseek.com/v1/chat/completions")!,
            apiKey: deepSeekKey
        )
    }

    func query(
        messages: [StreamingChatMessage],
        model: String,
        maxTokens: Int,
        onToken: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        currentTask = Task {
            do {
                let body: [String: Any] = [
                    "model": model,
                    "messages": messages.map { ["role": $0.role, "content": $0.content] },
                    "max_tokens": maxTokens,
                    "stream": true,
                ]

                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode)
                else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    onComplete(NetworkError.serverError(code))
                    return
                }

                for try await line in bytes.lines {
                    guard !Task.isCancelled else {
                        onComplete(nil)
                        return
                    }
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonStr = String(line.dropFirst(6))

                    if jsonStr == "[DONE]" {
                        onComplete(nil)
                        return
                    }

                    guard let jsonData = jsonStr.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let delta = choices.first?["delta"] as? [String: Any],
                          let content = delta["content"] as? String
                    else { continue }

                    onToken(content)
                }
                onComplete(nil)
            } catch {
                onComplete(error)
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}

// MARK: - WebSocket implementation (skeleton)

final class WebSocketStreamingService: NSObject, StreamingAIService {
    private let endpoint: URL
    private let apiKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var onToken: (@Sendable (String) -> Void)?
    private var onComplete: (@Sendable (Error?) -> Void)?

    init(endpoint: URL, apiKey: String) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        super.init()
    }

    func query(
        messages: [StreamingChatMessage],
        model: String,
        maxTokens: Int,
        onToken: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        self.onToken = onToken
        self.onComplete = onComplete

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session?.webSocketTask(with: request)

        // Send query as JSON message
        let payload: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": maxTokens,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            webSocketTask?.send(.data(data)) { _ in }
        }

        webSocketTask?.resume()
        receiveNext()
    }

    func cancel() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        onComplete = nil
        onToken = nil
    }

    private func receiveNext() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.onToken?(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.onToken?(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveNext()

            case .failure(let error):
                self?.onComplete?(error)
            }
        }
    }
}

extension WebSocketStreamingService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onComplete?(nil)
    }
}
