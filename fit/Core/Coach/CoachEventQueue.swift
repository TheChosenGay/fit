import Foundation

// MARK: - Event queue with trigger logic

final class CoachEventQueue {
    private var events: [CoachEvent] = []
    private var lastTriggerTime: Date = .distantPast
    private let minInterval: TimeInterval = 2.0
    private let maxIdleInterval: TimeInterval = 5.0

    func enqueue(_ event: CoachEvent) {
        events.append(event)
    }

    func drain() -> [CoachEvent] {
        let result = events
        events.removeAll()
        return result
    }

    func shouldTrigger(isStreaming: Bool) -> Bool {
        guard !events.isEmpty else { return false }

        let hasUserSpeech = events.contains { if case .userSpeech = $0 { true } else { false } }
        let hasUrgent = events.contains(where: { $0.isUrgent })

        if hasUserSpeech { return true }
        if hasUrgent { return true }

        let now = Date()
        if !isStreaming, now.timeIntervalSince(lastTriggerTime) >= minInterval { return true }
        if now.timeIntervalSince(lastTriggerTime) >= maxIdleInterval { return true }

        return false
    }

    func markTriggered() {
        lastTriggerTime = Date()
    }
}
