import Foundation

// MARK: - Streaming chat message

struct StreamingChatMessage: Encodable {
    let role: String
    let content: String
}

// MARK: - Protocol

protocol StreamingAIService {
    /// Returns an AsyncThrowingStream that yields tokens one by one.
    func streamChat(
        messages: [StreamingChatMessage],
        model: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error>

    /// Cancel the current streaming request.
    func cancel()
}

extension StreamingAIService {
    /// Callback-based convenience wrapper around `streamChat`.
    func query(
        messages: [StreamingChatMessage],
        model: String,
        maxTokens: Int,
        onToken: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (Error?) -> Void
    ) {
        let stream = streamChat(messages: messages, model: model, maxTokens: maxTokens)
        Task {
            do {
                for try await token in stream {
                    onToken(token)
                }
                onComplete(nil)
            } catch {
                onComplete(error)
            }
        }
    }
}

// MARK: - HTTP SSE implementation

final class HTTPStreamingService: StreamingAIService {
    private let endpoint: EndPoint
    private let apiKey: String
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    init(endpoint: EndPoint = .deepseek, apiKey: String = Secrets.deepseekAPIKey) {
        self.endpoint = endpoint
        self.apiKey = apiKey
    }

    func streamChat(
        messages: [StreamingChatMessage],
        model: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation

            Task {
                do {
                    let body: [String: Any] = [
                        "model": model,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "max_tokens": maxTokens,
                        "stream": true,
                    ]
                    let bodyData = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, _) = try await NetworkService.shared.streamRequest(
                        endpoint: endpoint,
                        body: bodyData,
                        authKey: apiKey
                    )

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))

                        if jsonStr == "[DONE]" {
                            continuation.finish()
                            return
                        }

                        guard let jsonData = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String
                        else { continue }

                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func cancel() {
        continuation?.finish()
        continuation = nil
    }
}

// MARK: - WebSocket implementation (skeleton)

final class WebSocketStreamingService: NSObject, StreamingAIService {
    private let endpoint: EndPoint
    private let apiKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    init(endpoint: EndPoint = .deepseek, apiKey: String = Secrets.deepseekAPIKey) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        super.init()
    }

    func streamChat(
        messages: [StreamingChatMessage],
        model: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation

            guard let url = endpoint.url else {
                continuation.finish(throwing: NetworkError.invalidURL)
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 30

            session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            webSocketTask = session?.webSocketTask(with: request)

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
    }

    func cancel() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        continuation?.finish()
        continuation = nil
    }

    private func receiveNext() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.continuation?.yield(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.continuation?.yield(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveNext()

            case .failure(let error):
                self?.continuation?.finish(throwing: error)
            }
        }
    }
}

extension WebSocketStreamingService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        continuation?.finish()
    }
}
