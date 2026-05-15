import Foundation

// MARK: - Supported exercises

enum SupportedExercise: String, CaseIterable, Identifiable {
    case squat
    case pushup
    case plank
    case deadlift

    var id: String { rawValue }

    var chineseName: String {
        switch self {
        case .squat: return "深蹲"
        case .pushup: return "俯卧撑"
        case .plank: return "平板支撑"
        case .deadlift: return "硬拉"
        }
    }

    var targetJoints: Set<String> {
        switch self {
        case .squat:
            return ["left_upLeg_joint", "left_leg_joint", "left_foot_joint",
                    "right_upLeg_joint", "right_leg_joint", "right_foot_joint"]
        case .pushup:
            return ["left_shoulder_1_joint", "left_forearm_joint", "left_hand_joint",
                    "right_shoulder_1_joint", "right_forearm_joint", "right_hand_joint"]
        case .plank:
            return ["left_shoulder_1_joint", "left_upLeg_joint", "left_foot_joint",
                    "right_shoulder_1_joint", "right_upLeg_joint", "right_foot_joint"]
        case .deadlift:
            return ["left_shoulder_1_joint", "left_upLeg_joint", "left_leg_joint",
                    "right_shoulder_1_joint", "right_upLeg_joint", "right_leg_joint"]
        }
    }
}

enum ExercisePhase: String {
    case up
    case down
}

struct ExerciseFormResult {
    let exerciseName: String
    let repCount: Int
    let formScore: Int
    let feedback: String
}

// MARK: - Evaluator

struct ExerciseFormEvaluator {
    private var currentPhase: ExercisePhase = .up
    private var previousAngle: Float?
    private var repCount: Int = 0
    private var formScores: [Int] = []
    private var smoothAngle: Float?

    /// Angle threshold for rep transition
    private let downThreshold: Float = 90
    private let upThreshold: Float = 160
    private let angleSmoothing: Float = 0.3

    // MARK: - Evaluate

    mutating func evaluate(joints: BodyJoints, exercise: SupportedExercise) -> ExerciseFormResult {
        guard let angle = computeAngle(joints: joints, exercise: exercise) else {
            return ExerciseFormResult(
                exerciseName: exercise.chineseName,
                repCount: repCount,
                formScore: averageFormScore,
                feedback: "未检测到关键关节，请调整位置"
            )
        }

        // Smooth angle
        let filtered = smoothAngle.map { $0 * (1 - angleSmoothing) + angle * angleSmoothing } ?? angle
        smoothAngle = filtered

        // Update rep count via state machine
        updateRepCount(angle: filtered)

        // Score this frame
        let score = scoreForm(angle: filtered, exercise: exercise)
        formScores.append(score)
        if formScores.count > 60 { formScores.removeFirst() }

        // Build feedback
        let fb = buildFeedback(score: averageFormScore, exercise: exercise)

        return ExerciseFormResult(
            exerciseName: exercise.chineseName,
            repCount: repCount,
            formScore: averageFormScore,
            feedback: fb
        )
    }

    // MARK: - Reset

    mutating func reset() {
        currentPhase = .up
        previousAngle = nil
        repCount = 0
        formScores.removeAll()
        smoothAngle = nil
    }

    // MARK: - Angle computation

    private func computeAngle(joints: BodyJoints, exercise: SupportedExercise) -> Float? {
        let dict = Dictionary(uniqueKeysWithValues: joints.map { ($0.joint, $0) })

        func joint(_ name: String) -> BodyJoint? { dict[name] }

        switch exercise {
        case .squat:
            // Knee angle: hip → knee → ankle
            let hip = joint("left_upLeg_joint") ?? joint("right_upLeg_joint")
            let knee = joint("left_leg_joint") ?? joint("right_leg_joint")
            let ankle = joint("left_foot_joint") ?? joint("right_foot_joint")
            guard let h = hip, let k = knee, let a = ankle else { return nil }
            return angleBetween(a: h.location2D, b: k.location2D, c: a.location2D)

        case .pushup:
            // Elbow angle: shoulder → elbow → wrist
            let shoulder = joint("left_shoulder_1_joint") ?? joint("right_shoulder_1_joint")
            let elbow = joint("left_forearm_joint") ?? joint("right_forearm_joint")
            let wrist = joint("left_hand_joint") ?? joint("right_hand_joint")
            guard let s = shoulder, let e = elbow, let w = wrist else { return nil }
            return angleBetween(a: s.location2D, b: e.location2D, c: w.location2D)

        case .plank:
            // Hip deviation from shoulder-ankle line (vertical alignment)
            let shoulder = joint("left_shoulder_1_joint") ?? joint("right_shoulder_1_joint")
            let hip = joint("left_upLeg_joint") ?? joint("right_upLeg_joint")
            let ankle = joint("left_foot_joint") ?? joint("right_foot_joint")
            guard let s = shoulder, let h = hip, let a = ankle else { return nil }
            return hipDeviation(shoulder: s.location2D, hip: h.location2D, ankle: a.location2D)

        case .deadlift:
            // Back angle: shoulder → hip relative to vertical
            let shoulder = joint("left_shoulder_1_joint") ?? joint("right_shoulder_1_joint")
            let hip = joint("left_upLeg_joint") ?? joint("right_upLeg_joint")
            guard let s = shoulder, let h = hip else { return nil }
            return verticalAngle(a: s.location2D, b: h.location2D)
        }
    }

    private func angleBetween(a: CGPoint, b: CGPoint, c: CGPoint) -> Float {
        let v1x = a.x - b.x
        let v1y = a.y - b.y
        let v2x = c.x - b.x
        let v2y = c.y - b.y
        let dot = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)
        guard mag1 > 1e-6, mag2 > 1e-6 else { return 0 }
        return Float(acos(max(-1, min(1, dot / (mag1 * mag2)))) * 180 / .pi)
    }

    private func hipDeviation(shoulder: CGPoint, hip: CGPoint, ankle: CGPoint) -> Float {
        // Distance from hip to the line connecting shoulder and ankle
        let dx = ankle.x - shoulder.x
        let dy = ankle.y - shoulder.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 1e-6 else { return 0 }
        let t = ((hip.x - shoulder.x) * dx + (hip.y - shoulder.y) * dy) / lenSq
        let projX = shoulder.x + t * dx
        let projY = shoulder.y + t * dy
        let dist = sqrt((hip.x - projX) * (hip.x - projX) + (hip.y - projY) * (hip.y - projY))
        return Float(dist * 100) // Scale to reasonable range
    }

    private func verticalAngle(a: CGPoint, b: CGPoint) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let angle = abs(atan2(dx, dy) * 180 / .pi)
        return Float(angle)
    }

    // MARK: - Rep counting

    private mutating func updateRepCount(angle: Float) {
        switch currentPhase {
        case .up:
            if angle < downThreshold {
                currentPhase = .down
            }
        case .down:
            if angle > upThreshold {
                currentPhase = .up
                repCount += 1
            }
        }
        previousAngle = angle
    }

    // MARK: - Form scoring

    private var averageFormScore: Int {
        guard !formScores.isEmpty else { return 100 }
        return formScores.reduce(0, +) / formScores.count
    }

    private func scoreForm(angle: Float, exercise: SupportedExercise) -> Int {
        switch exercise {
        case .squat:
            // Ideal squat: deep enough (>90) with control
            if angle >= 80 && angle <= 170 { return 100 }
            if angle >= 70 && angle <= 175 { return 85 }
            return 65
        case .pushup:
            if angle >= 70 && angle <= 170 { return 100 }
            if angle >= 60 && angle <= 175 { return 85 }
            return 65
        case .plank:
            // Lower deviation is better
            if angle < 5 { return 100 }
            if angle < 10 { return 85 }
            if angle < 15 { return 70 }
            return 50
        case .deadlift:
            // Vertical back is ideal (< 10 degrees from vertical)
            if angle < 10 { return 100 }
            if angle < 20 { return 85 }
            if angle < 30 { return 70 }
            return 50
        }
    }

    // MARK: - Feedback

    private func buildFeedback(score: Int, exercise: SupportedExercise) -> String {
        if score >= 85 {
            return "动作标准，保持节奏"
        }
        if score >= 70 {
            return "注意控制幅度"
        }
        if score < 60 {
            switch exercise {
            case .squat: return "蹲得更深一些，保持背部挺直"
            case .pushup: return "核心收紧，身体保持一条直线"
            case .plank: return "臀部不要塌陷，收紧核心"
            case .deadlift: return "保持背部挺直，不要弓背"
            }
        }
        return "继续加油"
    }
}
