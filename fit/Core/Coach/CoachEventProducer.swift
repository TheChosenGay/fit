import Foundation

// MARK: - Frame-to-event producer

final class CoachEventProducer {
    private var formEvaluator = ExerciseFormEvaluator()
    private let exercise: SupportedExercise
    private var lastRepCount: Int = 0
    private var lastDeviationTime: Date = .distantPast
    private let deviationCooldown: TimeInterval = 3.0
    private var lastFormScoreEvent: Int?

    init(exercise: SupportedExercise) {
        self.exercise = exercise
    }

    func processFrame(_ joints: BodyJoints) -> (result: ExerciseFormResult, events: [CoachEvent]) {
        let result = formEvaluator.evaluate(joints: joints, exercise: exercise)
        var events: [CoachEvent] = []

        // Rep completed
        if result.repCount > lastRepCount {
            events.append(.repComplete(count: result.repCount, score: result.formScore))
            lastRepCount = result.repCount
        }

        // Low form score with cooldown and hysteresis
        let now = Date()
        if result.formScore < 70,
           now.timeIntervalSince(lastDeviationTime) >= deviationCooldown,
           lastFormScoreEvent == nil || abs(lastFormScoreEvent! - result.formScore) > 10 {
            events.append(.formScore(score: result.formScore, feedback: result.feedback))
            lastDeviationTime = now
            lastFormScoreEvent = result.formScore
        }

        return (result, events)
    }

    func reset() {
        formEvaluator.reset()
        lastRepCount = 0
        lastDeviationTime = .distantPast
        lastFormScoreEvent = nil
    }
}
