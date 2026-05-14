import Speech
import CoreMedia

final class SpeechRecognizer {
    nonisolated static let shared = SpeechRecognizer()

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var resultContinuation: CheckedContinuation<String?, Error>?
    private var latestTranscription: String?

    private init() {}
}

extension SpeechRecognizer: FitSpeechToTextService {

    func speechToText(from buffer: CMSampleBuffer) async throws -> String? {
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        if recognitionRequest == nil {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            recognitionRequest = request

            let prev = latestTranscription
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let error {
                    self.resultContinuation?.resume(throwing: error)
                    self.resultContinuation = nil
                    return
                }
                let text = result?.bestTranscription.formattedString
                self.latestTranscription = text
                if let text, text != prev, let c = self.resultContinuation {
                    self.resultContinuation = nil
                    c.resume(returning: text)
                }
            }
        }

        recognitionRequest?.appendAudioSampleBuffer(buffer)

        return try await withCheckedThrowingContinuation { continuation in
            self.resultContinuation = continuation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard let self, let c = self.resultContinuation else { return }
                self.resultContinuation = nil
                c.resume(returning: self.latestTranscription)
            }
        }
    }

    func stopRecognition() {
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        latestTranscription = nil
    }
}

enum SpeechError: LocalizedError {
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: return "语音识别器不可用"
        }
    }
}
