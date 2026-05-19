import Foundation
import Combine
import CoreMedia

// MARK: - Session state

enum SessionState {
    case idle
    case streaming
    case interrupted
}

// MARK: - Chat bubble (UI model)

struct ChatBubble: Identifiable {
    let id = UUID()
    let role: BubbleRole
    let text: String
}

enum BubbleRole {
    case user
    case ai
}

// MARK: - Real-time coach session

@available(iOS 17.0, *)
@MainActor
final class RealtimeCoachSession: ObservableObject {

    // MARK: Published

    @Published var conversationBubbles: [ChatBubble] = []
    @Published var currentAIText: String = ""
    @Published var sessionState: SessionState = .idle
    @Published var currentFormResult: ExerciseFormResult?

    // MARK: Dependencies

    private let streamingAI: StreamingAIService
    private let speechRecognizer: SpeechRecognizer
    private let textSpeaker: TextSpeaker
    private let eventQueue = CoachEventQueue()
    private var eventProducer: CoachEventProducer?

    // MARK: Internal state

    private var conversationHistory: [StreamingChatMessage] = []
    private var currentStreamTask: Task<Void, Never>?
    private var triggerCheckTimer: Timer?
    private var sentenceBuffer: String = ""

    // MARK: Init

    init(streamingAI: StreamingAIService) {
        self.streamingAI = streamingAI
        self.speechRecognizer = SpeechRecognizer.shared
        self.textSpeaker = TextSpeaker.shared
    }

    convenience init() {
        self.init(streamingAI: HTTPStreamingService())
    }

    // MARK: Lifecycle

    func startSession(exercise: SupportedExercise, systemPrompt: String) {
        eventProducer = CoachEventProducer(exercise: exercise)
        conversationHistory = [StreamingChatMessage(role: "system", content: systemPrompt)]
        eventQueue.markTriggered()

        triggerCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAndTrigger()
            }
        }
    }

    func endSession() {
        triggerCheckTimer?.invalidate()
        triggerCheckTimer = nil
        currentStreamTask?.cancel()
        currentStreamTask = nil
        streamingAI.cancel()
        textSpeaker.stopSpeaking()
        speechRecognizer.stopRecognition()
        sessionState = .idle
    }

    // MARK: Input

    func onPoseFrame(_ joints: BodyJoints) {
        guard let producer = eventProducer else { return }
        let (result, events) = producer.processFrame(joints)
        currentFormResult = result

        for event in events {
            eventQueue.enqueue(event)
        }
    }

    func onAudioBuffer(_ buffer: CMSampleBuffer) {
        Task { [weak self] in
            guard let self else { return }
            if let text = try? await self.speechRecognizer.speechToText(from: buffer),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.interruptForUser(text)
            }
        }
    }

    // MARK: Core loop

    private func checkAndTrigger() {
        let isStreaming = currentStreamTask != nil
        guard eventQueue.shouldTrigger(isStreaming: isStreaming) else { return }

        if currentStreamTask != nil {
            currentStreamTask?.cancel()
            streamingAI.cancel()
            textSpeaker.stopSpeaking()
        }
        sendRequest()
    }

    private func sendRequest() {
        eventQueue.markTriggered()

        let events = eventQueue.drain()
        let poseEvents = events.filter { if case .userSpeech = $0 { false } else { true } }

        if !poseEvents.isEmpty {
            let eventText = poseEvents.map(\.description).joined(separator: "\n")
            conversationHistory.append(StreamingChatMessage(role: "user", content: eventText))
        }

        // Trim history to keep context manageable (last 20 messages)
        if conversationHistory.count > 21 {
            let systemMsg = conversationHistory.first!
            conversationHistory = [systemMsg] + conversationHistory.suffix(20)
        }

        sentenceBuffer = ""
        currentAIText = ""

        currentStreamTask = Task { [weak self] in
            guard let self else { return }

            do {
                let stream = self.streamingAI.streamChat(
                    messages: self.conversationHistory,
                    model: "deepseek-chat",
                    maxTokens: 200
                )

                self.sessionState = .streaming

                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    self.handleStreamToken(token)
                }

                // Speak any remaining sentence fragment
                if !self.sentenceBuffer.isEmpty {
                    try? await self.textSpeaker.textToSpeech(self.sentenceBuffer)
                    self.sentenceBuffer = ""
                }

                // Save AI response to history
                let aiText = self.currentAIText
                if !aiText.isEmpty {
                    self.conversationHistory.append(StreamingChatMessage(role: "assistant", content: aiText))
                    self.conversationBubbles.append(ChatBubble(role: .ai, text: aiText))
                }
                self.currentAIText = ""
                self.sessionState = .idle

            } catch is CancellationError {
                self.sessionState = .idle
            } catch {
                self.sessionState = .idle
            }
        }
    }

    private func handleStreamToken(_ token: String) {
        currentAIText += token
        sentenceBuffer += token

        // Speak at sentence boundaries
        if let last = token.last, ["。", "！", "？", "，", ".", "!", "?", ","].contains(last) {
            let sentence = sentenceBuffer
            sentenceBuffer = ""
            Task { [weak self] in
                try? await self?.textSpeaker.textToSpeech(sentence)
            }
        }
    }

    private func interruptForUser(_ text: String) {
        textSpeaker.stopSpeaking()
        currentStreamTask?.cancel()
        streamingAI.cancel()
        currentStreamTask = nil
        sentenceBuffer = ""
        currentAIText = ""

        eventQueue.enqueue(.userSpeech(text: text))
        conversationHistory.append(StreamingChatMessage(role: "user", content: text))
        conversationBubbles.append(ChatBubble(role: .user, text: text))
        sessionState = .interrupted

        // checkAndTrigger will fire on next timer tick because userSpeech is in queue
    }
}

