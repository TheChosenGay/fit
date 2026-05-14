import AVFoundation

final class TextSpeaker {
    nonisolated static let shared = TextSpeaker()

    private let synthesizer = AVSpeechSynthesizer()
    private var delegateProxy: SynthesizerDelegateProxy?
    private var continuation: CheckedContinuation<Void, Error>?

    private init() {}

    private func setDelegate(onFinish: @escaping () -> Void) {
        let proxy = SynthesizerDelegateProxy(onFinish: onFinish)
        delegateProxy = proxy  // keep strong reference so delegate isn't deallocated
        synthesizer.delegate = proxy
    }
}

extension TextSpeaker: FitTextToSpeechService {

    func textToSpeech(_ text: String) async throws {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5

        setDelegate { [weak self] in
            self?.continuation?.resume()
            self?.continuation = nil
        }

        return try await withCheckedThrowingContinuation { c in
            continuation = c
            synthesizer.speak(utterance)
        }
    }

    func stopSpeaking() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        continuation?.resume()
        continuation = nil
    }
}

// MARK: - Delegate Proxy

private final class SynthesizerDelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }
}
