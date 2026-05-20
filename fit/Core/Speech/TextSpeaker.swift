import AVFoundation
import Combine

@MainActor
final class TextSpeaker: NSObject, ObservableObject {
    static let shared = TextSpeaker()

    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?
    @Published var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func stopSpeaking() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        onFinish?()
        onFinish = nil
    }
}

extension TextSpeaker: FitTextToSpeechService {

    func textToSpeech(_ text: String) async {
        // Wait for any in-progress utterance to finish
        while isSpeaking {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try? session.setActive(true)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5

        await withCheckedContinuation { c in
            isSpeaking = true
            onFinish = {
                c.resume()
            }
            synthesizer.speak(utterance)
        }
        isSpeaking = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            TextSpeaker.shared.onFinish?()
            TextSpeaker.shared.onFinish = nil
        }
    }
}
