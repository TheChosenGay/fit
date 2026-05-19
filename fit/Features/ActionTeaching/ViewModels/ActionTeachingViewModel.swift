import SwiftUI
import Combine

@available(iOS 17.0, *)
@MainActor
final class ActionTeachingViewModel: ObservableObject {

    enum PlaybackState {
        case idle
        case playing
        case paused
    }

    @Published var animatedJoints: BodyJoints?
    @Published var currentPhase: String = ""
    @Published var progressPercent: Float = 0
    @Published var playbackState: PlaybackState = .idle
    @Published var playbackSpeed: Float = 1.0

    private let actionService: StandardActionService
    private let animationService: SequenceAnimationService
    private var sequence: StandardActionSequence?
    private var playbackTask: Task<Void, Never>?

    init(
        actionService: StandardActionService = LocalStandardActionService(),
        animationService: SequenceAnimationService? = nil
    ) {
        self.actionService = actionService
        self.animationService = animationService ?? DefaultSequenceAnimationService(actionService: actionService)
    }

    @Published var errorMessage: String?

    func loadSequence(exerciseId: String) async {
        do {
            let loaded = try await actionService.loadSequence(exerciseId: exerciseId)
            if let loaded {
                sequence = loaded
            } else {
                errorMessage = "未找到动作序列文件: \(exerciseId)"
            }
        } catch {
            sequence = nil
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }

    func play() {
        guard let sequence else { return }
        playbackState = .playing

        playbackTask?.cancel()
        playbackTask = Task {
            let stream = animationService.playbackTimeline(
                sequence: sequence,
                playbackSpeed: playbackSpeed
            )
            for await (timeMs, joints) in stream {
                guard !Task.isCancelled else { break }
                animatedJoints = joints
                progressPercent = Float(timeMs) / Float(max(1, sequence.metadata.durationMs))
                currentPhase = phaseAtTime(timeMs, config: sequence.config)
            }
            if !Task.isCancelled {
                playbackState = .idle
            }
        }
    }

    func pause() {
        playbackTask?.cancel()
        playbackState = .paused
    }

    func stop() {
        playbackTask?.cancel()
        playbackState = .idle
        animatedJoints = nil
        progressPercent = 0
        currentPhase = ""
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if playbackState == .playing {
            play()
        }
    }

    private func phaseAtTime(_ timeMs: Int, config: SequenceConfig) -> String {
        var current = config.phaseMarkers.first?.phase ?? ""
        for marker in config.phaseMarkers where marker.timeMs <= timeMs {
            current = marker.phase
        }
        return current
    }
}
