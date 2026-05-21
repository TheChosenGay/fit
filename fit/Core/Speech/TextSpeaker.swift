import AVFoundation
import Combine

@MainActor
final class TextSpeaker: NSObject, ObservableObject {
    static let shared = TextSpeaker()

    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?
    @Published var isSpeaking = false
    private var generation = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func stopSpeaking() {
        generation += 1
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        onFinish?()
        onFinish = nil
    }
}

extension TextSpeaker: FitTextToSpeechService {

    func textToSpeech(_ text: String) async {
        let gen = generation

        // Wait for any in-progress utterance to finish
        while isSpeaking {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        // Bail if stopSpeaking() was called while waiting
        guard generation == gen else { return }

        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try? session.setActive(true)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5

        await withCheckedContinuation { c in
            // Check again before starting — stopSpeaking() may have fired
            guard generation == gen else {
                c.resume()
                return
            }
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
