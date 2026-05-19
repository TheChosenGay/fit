import SwiftUI

@available(iOS 17.0, *)
struct ActionTeachingView: View {

    @StateObject private var viewModel = ActionTeachingViewModel()
    let exerciseId: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Canvas { context, size in
                if let joints = viewModel.animatedJoints {
                    Skeleton3DRenderer.draw(
                        context: &context,
                        joints: joints,
                        canvasSize: size,
                        color: .blue,
                        baseOpacity: 0.8,
                        showLabels: true
                    )
                }
            }

            VStack {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 60)
                }

                Spacer()

                if !viewModel.currentPhase.isEmpty {
                    Text(viewModel.currentPhase)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                ProgressView(value: viewModel.progressPercent)
                    .tint(.blue)
                    .padding(.horizontal)

                HStack(spacing: 32) {
                    Button(action: { viewModel.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                    }

                    Button(action: {
                        switch viewModel.playbackState {
                        case .idle, .paused:
                            viewModel.play()
                        case .playing:
                            viewModel.pause()
                        }
                    }) {
                        Image(systemName: viewModel.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.title)
                    }

                    Menu {
                        Button("0.5x") { viewModel.setSpeed(0.5) }
                        Button("1.0x") { viewModel.setSpeed(1.0) }
                        Button("1.5x") { viewModel.setSpeed(1.5) }
                        Button("2.0x") { viewModel.setSpeed(2.0) }
                    } label: {
                        Text("\(viewModel.playbackSpeed, specifier: "%.1f")x")
                            .font(.subheadline.bold())
                    }
                }
                .foregroundColor(.white)
                .padding(.bottom, 32)
            }
        }
        .task {
            await viewModel.loadSequence(exerciseId: exerciseId)
            viewModel.play()
        }
    }
}
