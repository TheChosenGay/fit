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

    enum Zhipu {
        private static let base = "https://open.bigmodel.cn/api/paas/v4"
        static let chatCompletions = URL(string: "\(base)/chat/completions")!
    }

    enum MiniMax {
        private static let base = "https://api.minimax.chat/v1/text"
        static let chatCompletions = URL(string: "\(base)/chatcompletion_v2")!
    }
}
