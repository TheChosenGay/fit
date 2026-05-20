import Speech
import CoreMedia

@MainActor
final class SpeechRecognizer {
    static let shared = SpeechRecognizer()

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onUtterance: ((String) -> Void)?

    private var debounceTimer: Timer?
    private var pendingText: String?
    private var lastReported: String?

    private init() {}

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

extension SpeechRecognizer: FitSpeechToTextService {

    func startListening(onUtterance: @escaping (String) -> Void) throws {
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        stopRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        recognitionRequest = request

        self.onUtterance = onUtterance
        lastReported = nil

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self else { return }
            let text = result?.bestTranscription.formattedString

            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            if result?.isFinal == true, text != self.lastReported {
                self.cancelDebounce()
                self.lastReported = text
                self.onUtterance?(text)
                return
            }

            // Debounce partial results
            if text != self.pendingText {
                self.pendingText = text
                self.scheduleDebounceReport()
            }
        }
    }

    private func scheduleDebounceReport() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let text = self.pendingText,
                      text != self.lastReported else { return }
                self.lastReported = text
                self.onUtterance?(text)
            }
        }
    }

    private func cancelDebounce() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingText = nil
    }

    func appendAudio(_ buffer: CMSampleBuffer) {
        recognitionRequest?.appendAudioSampleBuffer(buffer)
    }

    func stopRecognition() {
        cancelDebounce()
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        lastReported = nil
        onUtterance = nil
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
