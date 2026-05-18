import Foundation
import simd

// MARK: - Comparison Result Types

struct AngleDeviation {
    let jointName: String
    let currentAngle: Float
    let standardAngle: Float
    let deviation: Float
    let feedback: String
}

struct PositionDeviation {
    let jointName: String
    let direction: String
    let magnitude: Float
    let feedback: String
}

struct FrameComparisonResult {
    let overallScore: Float
    let angleDeviations: [AngleDeviation]
    let positionDeviations: [PositionDeviation]
    let currentPhase: String
}

struct TimestampedBodyJoints {
    let timeMs: Int
    let joints: BodyJoints
}

// MARK: - Protocol

protocol SequenceComparisonService {
    func compareFrame(
        liveJoints: BodyJoints,
        referenceFrame: SequenceFrame,
        config: SequenceConfig
    ) -> FrameComparisonResult

    func detectPhase(
        liveJoints: BodyJoints,
        config: SequenceConfig
    ) -> String
}

// MARK: - Default Implementation

final class DefaultSequenceComparisonService: SequenceComparisonService {

    // MARK: - Angle definitions per joint triplet

    private struct AngleDef {
        let name: String
        let jointA: String
        let jointB: String
        let jointC: String
        let feedbackTemplate: String
    }

    private let angleDefs: [AngleDef] = [
        AngleDef(name: "left_knee", jointA: "left_hip", jointB: "left_knee", jointC: "left_ankle",
                 feedbackTemplate: "左膝弯曲"),
        AngleDef(name: "right_knee", jointA: "right_hip", jointB: "right_knee", jointC: "right_ankle",
                 feedbackTemplate: "右膝弯曲"),
        AngleDef(name: "left_hip", jointA: "left_shoulder", jointB: "left_hip", jointC: "left_knee",
                 feedbackTemplate: "左髋屈曲"),
        AngleDef(name: "right_hip", jointA: "right_shoulder", jointB: "right_hip", jointC: "right_knee",
                 feedbackTemplate: "右髋屈曲"),
        AngleDef(name: "left_elbow", jointA: "left_shoulder", jointB: "left_elbow", jointC: "left_wrist",
                 feedbackTemplate: "左肘弯曲"),
        AngleDef(name: "right_elbow", jointA: "right_shoulder", jointB: "right_elbow", jointC: "right_wrist",
                 feedbackTemplate: "右肘弯曲"),
        AngleDef(name: "left_shoulder", jointA: "left_hip", jointB: "left_shoulder", jointC: "left_elbow",
                 feedbackTemplate: "左臂与躯干夹角"),
        AngleDef(name: "right_shoulder", jointA: "right_hip", jointB: "right_shoulder", jointC: "right_elbow",
                 feedbackTemplate: "右臂与躯干夹角"),
    ]

    // MARK: - Compare Frame

    func compareFrame(
        liveJoints: BodyJoints,
        referenceFrame: SequenceFrame,
        config: SequenceConfig
    ) -> FrameComparisonResult {
        let liveDict = buildJointDict(from: liveJoints)
        let refDict = referenceFrame.joints

        let angleDeviations = computeAngleDeviations(live: liveDict, reference: refDict, config: config)
        let positionDeviations = computePositionDeviations(live: liveDict, reference: refDict, config: config)

        let angleScore = angleDeviations.isEmpty ? 100 : max(0, 100 - angleDeviations.map { abs($0.deviation) }.reduce(0, +) / Float(angleDeviations.count) * 2)
        let positionScore = positionDeviations.isEmpty ? 100 : max(0, 100 - positionDeviations.map { $0.magnitude }.reduce(0, +) / Float(positionDeviations.count) * 200)
        let overallScore = angleScore * 0.6 + positionScore * 0.4

        let phase = detectPhase(liveJoints: liveJoints, config: config)

        return FrameComparisonResult(
            overallScore: min(100, max(0, overallScore)),
            angleDeviations: angleDeviations,
            positionDeviations: positionDeviations,
            currentPhase: phase
        )
    }

    // MARK: - Phase Detection

    func detectPhase(liveJoints: BodyJoints, config: SequenceConfig) -> String {
        let dict = buildJointDict(from: liveJoints)

        guard let lHip = dict["left_hip"], let lKnee = dict["left_knee"], let lAnkle = dict["left_ankle"] else {
            return config.phaseMarkers.first?.phase ?? "unknown"
        }

        let kneeAngle = calculateAngle(a: lHip, b: lKnee, c: lAnkle)

        if kneeAngle > 160 { return "standing" }
        if kneeAngle > 120 { return "descending" }
        if kneeAngle < 90 { return "bottom" }
        return "ascending"
    }

    // MARK: - Angle Deviations

    private func computeAngleDeviations(
        live: [String: CGPoint],
        reference: [String: JointPosition3D],
        config: SequenceConfig
    ) -> [AngleDeviation] {
        var results: [AngleDeviation] = []
        let threshold: Float = 10

        for def in angleDefs {
            guard let lA = live[def.jointA], let lB = live[def.jointB], let lC = live[def.jointC],
                  let rA = reference[def.jointA], let rB = reference[def.jointB], let rC = reference[def.jointC]
            else { continue }

            let liveAngle = calculateAngle(a: lA, b: lB, c: lC)
            let refAngle = calculateAngle(
                a: CGPoint(x: CGFloat(rA.x), y: CGFloat(rA.y)),
                b: CGPoint(x: CGFloat(rB.x), y: CGFloat(rB.y)),
                c: CGPoint(x: CGFloat(rC.x), y: CGFloat(rC.y))
            )

            let deviation = liveAngle - refAngle
            guard abs(deviation) > threshold else { continue }

            let direction = deviation > 0 ? "过大" : "不足"
            let feedback = "\(def.feedbackTemplate)\(direction) \(Int(abs(deviation)))°"

            results.append(AngleDeviation(
                jointName: def.name,
                currentAngle: liveAngle,
                standardAngle: refAngle,
                deviation: deviation,
                feedback: feedback
            ))
        }

        return results
    }

    // MARK: - Position Deviations

    private func computePositionDeviations(
        live: [String: CGPoint],
        reference: [String: JointPosition3D],
        config: SequenceConfig
    ) -> [PositionDeviation] {
        var results: [PositionDeviation] = []

        let liveNorm = normalizePositions(live)
        let refNorm = normalizeRefPositions(reference)

        let tolerance = config.toleranceProfile.global
        let overrides = config.toleranceProfile.jointOverrides ?? [:]

        for joint in config.criticalJoints {
            guard let lp = liveNorm[joint], let rp = refNorm[joint] else { continue }

            let dx = Float(lp.x - rp.x)
            let dy = Float(lp.y - rp.y)
            let distance = sqrt(dx * dx + dy * dy)

            let jointTolerance = overrides[joint] ?? tolerance
            guard distance > jointTolerance else { continue }

            let (direction, feedback) = describeOffset(joint: joint, dx: dx, dy: dy)

            results.append(PositionDeviation(
                jointName: joint,
                direction: direction,
                magnitude: distance,
                feedback: feedback
            ))
        }

        return results
    }

    // MARK: - Normalization

    private func normalizePositions(_ joints: [String: CGPoint]) -> [String: CGPoint] {
        guard let root = joints["left_hip"].flatMap({ lh in
            joints["right_hip"].map { rh in
                CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            }
        }) else { return joints }

        guard let neck = joints["left_shoulder"].flatMap({ ls in
            joints["right_shoulder"].map { rs in
                CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            }
        }) else { return joints }

        let torsoLength = sqrt(pow(neck.x - root.x, 2) + pow(neck.y - root.y, 2))
        guard torsoLength > 0.01 else { return joints }

        var normalized: [String: CGPoint] = [:]
        for (name, point) in joints {
            normalized[name] = CGPoint(
                x: (point.x - root.x) / torsoLength,
                y: (point.y - root.y) / torsoLength
            )
        }
        return normalized
    }

    private func normalizeRefPositions(_ joints: [String: JointPosition3D]) -> [String: CGPoint] {
        guard let lh = joints["left_hip"], let rh = joints["right_hip"] else {
            return joints.mapValues { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        }
        let root = CGPoint(x: CGFloat((lh.x + rh.x) / 2), y: CGFloat((lh.y + rh.y) / 2))

        guard let ls = joints["left_shoulder"], let rs = joints["right_shoulder"] else {
            return joints.mapValues { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        }
        let neck = CGPoint(x: CGFloat((ls.x + rs.x) / 2), y: CGFloat((ls.y + rs.y) / 2))

        let torsoLength = sqrt(pow(neck.x - root.x, 2) + pow(neck.y - root.y, 2))
        guard torsoLength > 0.01 else {
            return joints.mapValues { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        }

        var normalized: [String: CGPoint] = [:]
        for (name, pos) in joints {
            normalized[name] = CGPoint(
                x: (CGFloat(pos.x) - root.x) / torsoLength,
                y: (CGFloat(pos.y) - root.y) / torsoLength
            )
        }
        return normalized
    }

    // MARK: - Helpers

    private func buildJointDict(from joints: BodyJoints) -> [String: CGPoint] {
        var dict: [String: CGPoint] = [:]
        for j in joints {
            let name = WholeBodyJointMap.legacyMapping.first(where: { $0.value == j.joint })?.key ?? j.joint
            dict[name] = j.location2D
        }
        return dict
    }

    private func calculateAngle(a: CGPoint, b: CGPoint, c: CGPoint) -> Float {
        let ba = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let bc = CGPoint(x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let magBA = sqrt(ba.x * ba.x + ba.y * ba.y)
        let magBC = sqrt(bc.x * bc.x + bc.y * bc.y)
        guard magBA > 0, magBC > 0 else { return 0 }
        let cosAngle = max(-1, min(1, dot / (magBA * magBC)))
        return Float(acos(cosAngle) * 180 / .pi)
    }

    private func describeOffset(joint: String, dx: Float, dy: Float) -> (String, String) {
        let jointNames: [String: String] = [
            "left_knee": "左膝", "right_knee": "右膝",
            "left_hip": "左髋", "right_hip": "右髋",
            "left_shoulder": "左肩", "right_shoulder": "右肩",
            "left_ankle": "左踝", "right_ankle": "右踝",
        ]
        let name = jointNames[joint] ?? joint

        if abs(dx) > abs(dy) {
            let dir = dx > 0 ? "偏右" : "偏左"
            return (dir, "\(name)\(dir)")
        } else {
            let dir = dy > 0 ? "偏低" : "偏高"
            return (dir, "\(name)\(dir)")
        }
    }
}
