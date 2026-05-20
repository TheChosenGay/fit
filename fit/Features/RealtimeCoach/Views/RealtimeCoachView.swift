import SwiftUI
import AVFoundation
import SwiftData

// MARK: - Real-time AI Coach View

@available(iOS 17.0, *)
struct RealtimeCoachView: View {
    let exercise: SupportedExercise

    @Environment(\.modelContext) private var modelContext

    @StateObject private var cameraVM = RealTimeCameraViewModel()
    @StateObject private var session = RealtimeCoachSession()
    @State private var isActive = false
    @State private var showExercisePicker = true
    @State private var audioCapture = AudioCapture()

    // Pre-workout advice
    @State private var workoutAdvice: WorkoutAdvice?
    @State private var isLoadingAdvice = false
    @State private var showAdvice = false

    private let healthDataService = DefaultHealthDataService()
    private let workoutDataService = DefaultWorkoutDataService()
    private let dietDataService = DefaultDietDataService()
    private let aiCoachService = DeepSeekAICoachService.shared

    private var systemPrompt: String {
        """
        你是一位专业的实时健身教练。你会收到用户运动时的姿态数据和语音。

        规则：
        1. 每次回复控制在1-3句话，简短有力
        2. 优先纠正动作问题，其次给予鼓励
        3. 用户问你问题时，直接回答，不要重复用户的话
        4. 不要说"根据数据显示"这类话，像面对面教练一样直接说
        5. 当姿态数据显示动作标准时，简短鼓励即可，不需要每次都说话
        6. 安全问题（膝盖内扣、背部弯曲过度）必须立即提醒

        当前运动：\(exercise.chineseName)
        """
    }

    var body: some View {
        ZStack {
            // Layer 1: Camera preview
            CameraPreviewView(session: cameraVM.cameraSession.session)
                .ignoresSafeArea()

            // Layer 2: Skeleton overlay
            if isActive, let joints = cameraVM.detectedJoints, !joints.isEmpty {
                GeometryReader { geo in
                    Canvas { context, _ in
                        var ctx = context
                        Skeleton3DRenderer.draw(
                            context: &ctx,
                            joints: joints,
                            canvasSize: geo.size,
                            isFrontCamera: cameraVM.isFrontCamera
                        )
                    }
                    .allowsHitTesting(false)
                }
            }

            // Layer 3: AI conversation overlay
            VStack {
                Spacer()

                // AI speaking text bubble
                if !session.currentAIText.isEmpty {
                    Text(session.currentAIText)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                // Form info bar
                if let result = session.currentFormResult {
                    HStack(spacing: 12) {
                        Label("\(result.repCount)次", systemImage: "repeat")
                        Label("\(result.formScore)分", systemImage: "star.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 8)
                }

                // Controls bar
                HStack(spacing: 20) {
                    Button(action: toggleSession) {
                        HStack(spacing: 6) {
                            Image(systemName: isActive ? "stop.fill" : "mic.fill")
                            Text(isActive ? "结束" : isLoadingAdvice ? "分析中..." : "开始教练")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isActive ? Color.red : Color.green)
                        .cornerRadius(24)
                    }
                    .disabled(isLoadingAdvice)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusLabel)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.bottom, 48)
            }

            // Exercise picker overlay
            if showExercisePicker {
                Color.black.opacity(0.4).ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("选择训练动作")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)

                    Picker("动作", selection: .constant(exercise)) {
                        ForEach(SupportedExercise.allCases) { ex in
                            Text(ex.chineseName).tag(ex)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .disabled(true)

                    Text("AI 教练将根据你的近期状态给出训练建议")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 60)
            }

            // Pre-workout advice overlay
            if showAdvice, let advice = workoutAdvice {
                Color.black.opacity(0.6).ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header
                    Image(systemName: advice.shouldTrain ? "figure.strengthtraining.functional" : "bed.double.fill")
                        .font(.system(size: 48))
                        .foregroundColor(advice.shouldTrain ? .green : .orange)

                    Text(advice.shouldTrain ? "今天适合训练" : "建议休息")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)

                    // Reason
                    Text(advice.reason)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Suggested focus
                    if let focus = advice.suggestedFocus, !focus.isEmpty {
                        VStack(spacing: 6) {
                            Text("建议重点")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                            Text(focus)
                                .font(.headline)
                                .foregroundColor(.dsPrimary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                    }

                    // Warnings
                    if let warnings = advice.warnings, !warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(warnings, id: \.self) { warning in
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(warning)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.15))
                        )
                    }

                    // Actions
                    HStack(spacing: 16) {
                        Button("取消") {
                            showAdvice = false
                            showExercisePicker = true
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)

                        Button(advice.shouldTrain ? "开始训练" : "仍要训练") {
                            showAdvice = false
                            beginSession()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(advice.shouldTrain ? Color.green : Color.orange)
                        .cornerRadius(24)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(32)
            }
        }
        .onAppear {
            do {
                try cameraVM.setupCamera()
            } catch {
                cameraVM.errorMessage = error.localizedDescription
            }
        }
        .onDisappear {
            stopSession()
            cameraVM.stopCamera()
        }
        .onChange(of: cameraVM.detectedJoints) { _, joints in
            guard isActive, let joints else { return }
            session.onPoseFrame(joints)
        }
    }

    // MARK: - Actions

    private func toggleSession() {
        if isActive {
            stopSession()
        } else {
            requestPreWorkoutAdvice()
        }
    }

    private func requestPreWorkoutAdvice() {
        isLoadingAdvice = true
        showExercisePicker = false

        Task {
            do {
                let advice = try await fetchPreWorkoutAdvice()
                await MainActor.run {
                    isLoadingAdvice = false
                    workoutAdvice = advice
                    showAdvice = true
                }
            } catch {
                await MainActor.run {
                    isLoadingAdvice = false
                    // On error, skip advice and start directly
                    beginSession()
                }
            }
        }
    }

    private func fetchPreWorkoutAdvice() async throws -> WorkoutAdvice {
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: endDate)) else {
            throw AIAnalysisError.invalidJSON
        }

        // Fetch 7-day data
        let healthData = (try? healthDataService.fetchHealthRange(from: startDate, to: endDate, context: modelContext)) ?? []
        let recentWorkouts = (try? workoutDataService.fetchRecentSessions(days: 7, context: modelContext)) ?? []
        let recentMeals = (try? dietDataService.fetchMealsRange(from: startDate, to: endDate, context: modelContext)) ?? []

        // Fetch profile
        var fetchDescriptor = FetchDescriptor<UserProfile>()
        fetchDescriptor.fetchLimit = 1
        let profile = try? modelContext.fetch(fetchDescriptor).first

        let context = CoachContextBuilder.buildPreWorkoutContext(
            profile: profile,
            healthData: healthData,
            recentWorkouts: recentWorkouts,
            recentMeals: recentMeals
        )

        let allExercises = SupportedExercise.allCases.map(\.chineseName)
        return try await aiCoachService.preWorkoutAdvice(context: context, supportedExercises: allExercises)
    }

    private func beginSession() {
        cameraVM.startDetection()
        audioCapture.start { buffer in
            session.onAudioBuffer(buffer)
        }
        session.startSession(exercise: exercise, systemPrompt: systemPrompt)
        isActive = true
    }

    private func stopSession() {
        isActive = false
        showExercisePicker = true
        session.endSession()
        cameraVM.stopDetection()
        audioCapture.stop()
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch session.sessionState {
        case .idle: return .gray
        case .streaming: return .green
        case .interrupted: return .orange
        }
    }

    private var statusLabel: String {
        switch session.sessionState {
        case .idle: return "待机"
        case .streaming: return "AI 指导中"
        case .interrupted: return "聆听中"
        }
    }
}

// MARK: - Audio Capture (CMSampleBuffer-based)

@available(iOS 17.0, *)
private final class AudioCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "audio.capture")
    private var onBuffer: ((CMSampleBuffer) -> Void)?

    func start(onBuffer: @escaping (CMSampleBuffer) -> Void) {
        self.onBuffer = onBuffer

        guard let mic = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: mic) else { return }

        session.beginConfiguration()
        guard session.canAddInput(input) else { session.commitConfiguration(); return }
        session.addInput(input)

        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return }
        session.addOutput(output)
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        session.stopRunning()
        onBuffer = nil
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onBuffer?(sampleBuffer)
    }
}
