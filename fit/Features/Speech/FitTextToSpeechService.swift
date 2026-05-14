import Foundation

/// 语音合成服务
protocol FitTextToSpeechService {
    func textToSpeech(_ text: String) async throws
    func stopSpeaking()
}
