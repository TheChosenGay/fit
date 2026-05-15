import SwiftUI
import AVKit

@available(iOS 17.0, *)
struct WorkoutSessionView: View {
    @StateObject private var viewModel = WorkoutSessionViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showExercisePicker = true
    @State private var showPlayer = false
    @State private var showSummary = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showExercisePicker {
                exercisePickerView
            } else {
                sessionView
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let url = viewModel.recordedVideoURL {
                VideoPlayerView(url: url, isPresented: $showPlayer)
            }
        }
        .sheet(isPresented: $showSummary) {
            summaryView
        }
        .task {
            do { try viewModel.setupCamera() } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .onDisappear { viewModel.stopCamera() }
    }

    // MARK: - Exercise picker

    private var exercisePickerView: some View {
        VStack(spacing: DSSpacing.xl) {
            Text("选择训练动作")
                .dsTextStyle(.title2)
                .foregroundColor(.white)

            ForEach(SupportedExercise.allCases) { exercise in
                Button {
                    showExercisePicker = false
                    viewModel.startSession(exercise: exercise)
                } label: {
                    HStack(spacing: DSSpacing.md) {
                        Image(systemName: exerciseIcon(exercise))
                            .font(.title2)
                            .foregroundColor(.dsPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.dsPrimary.opacity(0.15))
                            .cornerRadius(DSCornerRadius.small)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.chineseName)
                                .dsTextStyle(.headline)
                                .foregroundColor(.white)
                            Text(exerciseDescription(exercise))
                                .dsTextStyle(.caption1)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(DSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .padding(.horizontal, DSSpacing.lg)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("返回")
                    .dsTextStyle(.body)
                    .foregroundColor(.dsLabelSecondary)
            }
            .padding(.bottom, DSSpacing.xl)
        }
        .padding(.top, DSSpacing.huge)
    }

    // MARK: - Session view

    private var sessionView: some View {
        ZStack {
            // Camera background
            CameraPreviewView(session: viewModel.cameraSession.session)
                .ignoresSafeArea()

            // Skeleton overlay
            if viewModel.isSessionRunning, let joints = viewModel.detectedJoints, !joints.isEmpty {
                GeometryReader { geo in
                    Canvas { context, _ in
                        var ctx = context
                        Skeleton3DRenderer.draw(
                            context: &ctx,
                            joints: joints,
                            canvasSize: geo.size,
                            isFrontCamera: viewModel.isFrontCamera
                        )
                    }
                    .allowsHitTesting(false)
                }
            }

            // Top bar
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.exerciseName)
                            .font(.headline)
                            .foregroundColor(.white)

                        if viewModel.isSessionRunning {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                Text(formatDuration(viewModel.sessionDuration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }

                    Spacer()

                    Button(action: { viewModel.flipCamera() }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Coaching cue
                if !viewModel.lastCoachingCue.isEmpty {
                    Text(viewModel.lastCoachingCue)
                        .dsTextStyle(.caption1)
                        .foregroundColor(.white)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, DSSpacing.xs)
                        .background(.ultraThinMaterial)
                        .cornerRadius(DSCornerRadius.small)
                        .padding(.horizontal, DSSpacing.xxl)
                }

                // Bottom dashboard
                bottomDashboard
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Bottom dashboard

    private var bottomDashboard: some View {
        HStack(spacing: DSSpacing.xl) {
            // Rep counter
            VStack(spacing: 4) {
                Text("\(viewModel.repCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("次数")
                    .dsTextStyle(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 80)

            Divider()
                .frame(height: 48)
                .background(Color.white.opacity(0.2))

            // Form score
            VStack(spacing: 4) {
                Text("\(viewModel.formScore)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor(viewModel.formScore))
                Text("评分")
                    .dsTextStyle(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 80)

            Divider()
                .frame(height: 48)
                .background(Color.white.opacity(0.2))

            // End session button
            Button {
                viewModel.endSession(context: modelContext)
                showSummary = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.red)
                    Text("结束")
                        .dsTextStyle(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.vertical, DSSpacing.md)
        .background(.ultraThinMaterial)
        .cornerRadius(DSCornerRadius.large)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Summary sheet

    private var summaryView: some View {
        VStack(spacing: DSSpacing.lg) {
            Text("训练完成")
                .dsTextStyle(.title2)
                .foregroundColor(.white)
                .padding(.top, DSSpacing.xxl)

            HStack(spacing: DSSpacing.xxl) {
                summaryItem(value: "\(viewModel.repCount)", label: "总次数")
                summaryItem(value: "\(viewModel.formScore)", label: "平均评分", color: scoreColor(viewModel.formScore))
                summaryItem(value: formatDuration(viewModel.sessionDuration), label: "时长")
            }

            if viewModel.recordedVideoURL != nil {
                Button {
                    showPlayer = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle")
                        Text("查看录制")
                    }
                    .dsTextStyle(.body)
                    .foregroundColor(.dsPrimary)
                }
            }

            Spacer()

            Button {
                showSummary = false
                dismiss()
            } label: {
                Text("保存并退出")
                    .dsTextStyle(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.dsPrimary)
                    .cornerRadius(DSCornerRadius.medium)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xl)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func summaryItem(value: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .dsTextStyle(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .dsSuccess }
        if score >= 60 { return .dsWarning }
        return .dsError
    }

    private func exerciseIcon(_ exercise: SupportedExercise) -> String {
        switch exercise {
        case .squat: return "figure.strengthtraining.traditional"
        case .pushup: return "figure.strengthtraining.functional"
        case .plank: return "figure.core.training"
        case .deadlift: return "figure.strengthtraining.traditional"
        }
    }

    private func exerciseDescription(_ exercise: SupportedExercise) -> String {
        switch exercise {
        case .squat: return "锻炼下肢力量，改善体态"
        case .pushup: return "锻炼上肢和核心肌群"
        case .plank: return "核心稳定性训练"
        case .deadlift: return "全身复合动作，增强后链"
        }
    }
}
