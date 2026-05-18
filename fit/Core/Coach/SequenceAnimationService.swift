import Foundation

// MARK: - Protocol

protocol SequenceAnimationService {
    func frameToBodyJoints(frame: SequenceFrame) -> BodyJoints
    func playbackTimeline(sequence: StandardActionSequence, playbackSpeed: Float) -> AsyncStream<(timeMs: Int, joints: BodyJoints)>
}

// MARK: - Default Implementation
@available(iOS 17.0, *)
final class DefaultSequenceAnimationService: SequenceAnimationService {

    private let actionService: StandardActionService

    init(actionService: StandardActionService) {
        self.actionService = actionService
    }

    func frameToBodyJoints(frame: SequenceFrame) -> BodyJoints {
        var joints: BodyJoints = []

        for (name, pos) in frame.joints {
            let legacyName = WholeBodyJointMap.legacyMapping[name] ?? name
            joints.append(BodyJoint(
                joint: legacyName,
                location2D: CGPoint(x: CGFloat(pos.x), y: CGFloat(pos.y)),
                position3D: nil,
                confidence: 1.0
            ))
        }

        if let ls = frame.joints["left_shoulder"], let rs = frame.joints["right_shoulder"] {
            joints.append(BodyJoint(
                joint: "neck_1_joint",
                location2D: CGPoint(x: CGFloat((ls.x + rs.x) / 2), y: CGFloat((ls.y + rs.y) / 2)),
                position3D: nil,
                confidence: 1.0
            ))
        }

        if let lh = frame.joints["left_hip"], let rh = frame.joints["right_hip"] {
            joints.append(BodyJoint(
                joint: "root",
                location2D: CGPoint(x: CGFloat((lh.x + rh.x) / 2), y: CGFloat((lh.y + rh.y) / 2)),
                position3D: nil,
                confidence: 1.0
            ))
        }

        return joints
    }

    func playbackTimeline(
        sequence: StandardActionSequence,
        playbackSpeed: Float
    ) -> AsyncStream<(timeMs: Int, joints: BodyJoints)> {
        let service = actionService
        let animService = self
        let fps = sequence.config.fps
        let duration = sequence.metadata.durationMs
        let isLoopable = sequence.config.isLoopable
        let speed = max(0.1, playbackSpeed)

        return AsyncStream { continuation in
            let task = Task {
                let frameInterval = 1_000_000_000 / UInt64(Float(fps) * speed)
                var currentTimeMs = 0
                let stepMs = Int(1000.0 / (Float(fps) * speed))

                while !Task.isCancelled {
                    let frame = service.interpolateFrame(sequence: sequence, atTimeMs: currentTimeMs)
                    let joints = animService.frameToBodyJoints(frame: frame)
                    continuation.yield((timeMs: currentTimeMs, joints: joints))

                    try? await Task.sleep(nanoseconds: frameInterval)
                    currentTimeMs += stepMs

                    if !isLoopable && currentTimeMs > duration {
                        break
                    }
                    if isLoopable {
                        currentTimeMs = currentTimeMs % duration
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
