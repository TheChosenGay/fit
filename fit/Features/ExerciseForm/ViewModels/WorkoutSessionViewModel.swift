import SwiftUI
import Combine
import AVFoundation
import SwiftData

@available(iOS 17.0, *)
@MainActor
final class WorkoutSessionViewModel: ObservableObject {

    let cameraSession = CameraSession()
    private var frameProcessor: PoseFrameProcessor
    private var formEvaluator = ExerciseFormEvaluator()
    private let controlQueue = DispatchQueue(label: "workout.session.control")

    // Services
    private let coachService: AICoachService = DeepSeekAICoachService.shared
    private let tts = TextSpeaker.shared

    // Published state
    @Published var selectedExercise: SupportedExercise = .squat
    @Published var detectedJoints: BodyJoints?
    @Published var isSessionRunning = false
    @Published var isFrontCamera = false
    @Published var repCount: Int = 0
    @Published var formScore: Int = 100
    @Published var lastCoachingCue: String = ""
    @Published var exerciseName: String = "深蹲"
    @Published var sessionDuration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var recordedVideoURL: URL?

    // Internal state
    private var coachingTimer: Timer?
    private var durationTimer: Timer?
    private var lastFeedbackTime: Date = .distantPast
    private var isRequestingFeedback = false
    private var sessionStartTime: Date = .now

    init(backend: PoseDetectorBackend = .rtmPose) {
        self.frameProcessor = PoseFrameProcessor(backend: backend)
    }

    // MARK: - Camera

    func setupCamera() throws {
        controlQueue.sync {}
        try cameraSession.configure(position: .back)
        cameraSession.start()
    }

    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        do {
            try cameraSession.switchCamera(to: newPosition)
            isFrontCamera.toggle()
            if isSessionRunning {
                let wasRunning = true
                stopPipeline()
                if wasRunning { startPipeline() }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Session

    func startSession(exercise: SupportedExercise) {
        guard !isSessionRunning else { return }
        selectedExercise = exercise
        exerciseName = exercise.chineseName
        formEvaluator.reset()
        repCount = 0
        formScore = 100
        lastCoachingCue = "准备开始"
        sessionStartTime = Date()

        startPipeline()
        isSessionRunning = true
    }

    func endSession(context: ModelContext) {
        stopPipeline()

        let duration = Date().timeIntervalSince(sessionStartTime)
        let session = WorkoutSession()
        session.date = sessionStartTime
        session.durationSeconds = Int(duration)
        session.totalReps = repCount
        session.averageFormScore = Double(formScore)
        session.caloriesBurned = Double(Int(duration / 60) * 5)

        let exercise = WorkoutExercise()
        exercise.exerciseName = selectedExercise.chineseName
        exercise.repsPerSet = [repCount]
        exercise.formScores = [Double(formScore)]
        exercise.coachingTipsReceived = [lastCoachingCue]
        session.exercises?.append(exercise)

        do {
            try DefaultWorkoutDataService().saveSession(session, context: context)
        } catch {
            errorMessage = "保存训练失败: \(error.localizedDescription)"
        }
    }

    func stopCamera() {
        stopPipeline()
        if let url = frameProcessor.stopRecording() {
            recordedVideoURL = url
        }
        controlQueue.async { [weak self] in
            self?.cameraSession.stop()
        }
    }

    // MARK: - Private pipeline

    private func startPipeline() {
        let fileName = "workout_\(Int(Date().timeIntervalSince1970)).mov"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
        frameProcessor.startRecording(to: fileURL, isFrontCamera: isFrontCamera)

        cameraSession.frameHandler = { [weak self] buffer in
            self?.frameProcessor.processFrame(buffer)
        }

        frameProcessor.onPoseDetected = { [weak self] joints in
            guard let self else { return }
            self.detectedJoints = joints
            self.evaluateForm(joints: joints)
        }

        frameProcessor.onPoseLost = { [weak self] in
            self?.detectedJoints = nil
        }

        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sessionDuration = Date().timeIntervalSince(self.sessionStartTime)
        }

        // Coaching timer (every 3 seconds)
        coachingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.requestCoachingCue()
            }
        }
    }

    private func stopPipeline() {
        cameraSession.frameHandler = nil
        frameProcessor.onPoseDetected = nil
        frameProcessor.onPoseLost = nil
        coachingTimer?.invalidate()
        coachingTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        isSessionRunning = false
        detectedJoints = nil
    }

    // MARK: - Form evaluation

    private func evaluateForm(joints: BodyJoints) {
        let result = formEvaluator.evaluate(joints: joints, exercise: selectedExercise)
        repCount = result.repCount
        formScore = result.formScore
        if result.feedback != lastCoachingCue && !result.feedback.isEmpty {
            lastCoachingCue = result.feedback
        }
    }

    // MARK: - AI coaching

    private func requestCoachingCue() async {
        guard !isRequestingFeedback else { return }
        isRequestingFeedback = true
        defer { isRequestingFeedback = false }

        let context = CoachContextBuilder.buildRealTimeContext(
            profile: nil,
            exerciseName: selectedExercise.chineseName,
            formScore: formScore,
            recentReps: repCount
        )

        do {
            let cue = try await coachService.realTimeFeedback(
                context: context,
                exerciseName: selectedExercise.chineseName,
                formScore: formScore,
                recentReps: repCount
            )
            await MainActor.run {
                self.lastCoachingCue = cue
            }
            // Speak the cue
            try? await tts.textToSpeech(cue)
        } catch {
            print("[WorkoutSession] AI feedback failed: \(error)")
        }
    }
}
