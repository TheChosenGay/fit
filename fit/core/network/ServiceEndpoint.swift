import Foundation

enum ServiceEndpoint {
    enum Claude {
        private static let base = "https://api.anthropic.com"
        static let messages = URL(string: "\(base)/v1/messages")!
    }

    enum OpenAI {
        private static let base = "https://api.openai.com"
        static let chatCompletions = URL(string: "\(base)/v1/chat/completions")!
    }

    enum DeepSeek {
        private static let base = "https://api.deepseek.com"
        static let chatCompletions = URL(string: "\(base)/v1/chat/completions")!
    }
}
