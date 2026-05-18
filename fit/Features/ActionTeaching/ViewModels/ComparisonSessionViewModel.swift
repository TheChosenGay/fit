import SwiftUI
import Combine

@available(iOS 17.0, *)
@MainActor
final class ComparisonSessionViewModel: ObservableObject {

    @Published var liveJoints: BodyJoints?
    @Published var referenceJoints: BodyJoints?
    @Published var comparisonResult: FrameComparisonResult?
    @Published var isActive = false

    private let actionService: StandardActionService
    private let comparisonService: SequenceComparisonService
    private let animationService: SequenceAnimationService
    private var sequence: StandardActionSequence?

    init(
        actionService: StandardActionService = LocalStandardActionService(),
        comparisonService: SequenceComparisonService = DefaultSequenceComparisonService()
    ) {
        self.actionService = actionService
        self.comparisonService = comparisonService
        self.animationService = DefaultSequenceAnimationService(actionService: actionService)
    }

    func loadSequence(exerciseId: String) async {
        sequence = try? await actionService.loadSequence(exerciseId: exerciseId)
    }

    func onPoseDetected(joints: BodyJoints) {
        guard let sequence else { return }
        liveJoints = joints

        let phase = comparisonService.detectPhase(liveJoints: joints, config: sequence.config)

        guard let phaseTimeMs = sequence.config.phaseMarkers.first(where: { $0.phase == phase })?.timeMs else {
            return
        }

        let refFrame = actionService.interpolateFrame(sequence: sequence, atTimeMs: phaseTimeMs)
        referenceJoints = animationService.frameToBodyJoints(frame: refFrame)

        comparisonResult = comparisonService.compareFrame(
            liveJoints: joints,
            referenceFrame: refFrame,
            config: sequence.config
        )
    }
}
