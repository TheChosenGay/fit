import SwiftUI
import AVFoundation

// MARK: - Real-time AI Coach View

@available(iOS 17.0, *)
struct RealtimeCoachView: View {
    let exercise: SupportedExercise

    @StateObject private var cameraVM = RealTimeCameraViewModel()
    @StateObject private var session = RealtimeCoachSession()
    @State private var isActive = false
    @State private var showExercisePicker = true
    @State private var audioCapture = AudioCapture()

    private let systemPrompt: String = {
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
    }()

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
                            Text(isActive ? "结束" : "开始教练")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isActive ? Color.red : Color.green)
                        .cornerRadius(24)
                    }

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

            // Exercise picker overlay (before starting)
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

                    Text("开始后 AI 教练将实时指导你的动作")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 60)
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
            startSession()
        }
    }

    private func startSession() {
        showExercisePicker = false
        cameraVM.startDetection()
        audioCapture.start { buffer in
            session.onAudioBuffer(buffer)
        }
        session.startSession(exercise: exercise, systemPrompt: systemPrompt)
        isActive = true
    }

    private func stopSession() {
        isActive = false
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
