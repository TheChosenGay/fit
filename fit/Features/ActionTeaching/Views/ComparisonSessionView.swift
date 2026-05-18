import SwiftUI
import AVFoundation

@available(iOS 17.0, *)
struct ComparisonSessionView: View {

    @StateObject private var viewModel = ComparisonSessionViewModel()
    @Environment(\.dismiss) private var dismiss
    let exerciseId: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Dual skeleton overlay
            Canvas { context, size in
                // Reference skeleton (blue)
                if let refJoints = viewModel.referenceJoints {
                    Skeleton3DRenderer.draw(
                        context: &context,
                        joints: refJoints,
                        canvasSize: size,
                        color: .blue,
                        baseOpacity: 0.5,
                        showLabels: false
                    )
                }
                // User live skeleton (green)
                if let liveJoints = viewModel.liveJoints {
                    Skeleton3DRenderer.draw(
                        context: &context,
                        joints: liveJoints,
                        canvasSize: size,
                        isFrontCamera: true,
                        color: .green,
                        baseOpacity: 1.0,
                        showLabels: false
                    )
                }
            }

            // Score overlay
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    scoreView
                }
                .padding()

                Spacer()

                feedbackView
                    .padding(.bottom, 40)
            }
        }
        .task {
            await viewModel.loadSequence(exerciseId: exerciseId)
        }
    }

    // MARK: - Score

    private var scoreView: some View {
        Group {
            if let result = viewModel.comparisonResult {
                VStack(spacing: 2) {
                    Text("\(Int(result.overallScore))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor(result.overallScore))
                    Text(result.currentPhase)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Feedback

    private var feedbackView: some View {
        Group {
            if let result = viewModel.comparisonResult {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.angleDeviations.prefix(2), id: \.jointName) { dev in
                        HStack(spacing: 6) {
                            Circle().fill(.orange).frame(width: 6, height: 6)
                            Text(dev.feedback)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    ForEach(result.positionDeviations.prefix(2), id: \.jointName) { dev in
                        HStack(spacing: 6) {
                            Circle().fill(.yellow).frame(width: 6, height: 6)
                            Text(dev.feedback)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    private func scoreColor(_ score: Float) -> Color {
        switch score {
        case 80...: return .green
        case 60...: return .yellow
        default: return .orange
        }
    }
}
