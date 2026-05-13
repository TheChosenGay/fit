import Foundation
import simd
import CoreMedia

// MARK: - BodyJoint (combined 2D + 3D)

struct BodyJoint {
    let joint: String
    let location2D: CGPoint          // normalized 0-1 (from 2D detection, for screen overlay)
    let position3D: simd_float3?     // 3D world position in meters (from 3D detection, for analysis)
    let confidence: Float
}

typealias BodyJoints = [BodyJoint]

// MARK: - PosePoint3D (3D-only, legacy)

struct PosePoint3D {
    let joint: String
    let position: simd_float3
    let positionConfidence: Float
    let confidence: Float
    let location2D: CGPoint
}

typealias PosePoints3D = [PosePoint3D]

// MARK: - 3D Detection Protocol

protocol PoseDetectService3D {
    func detectPose3D(from sampleBuffer: CMSampleBuffer) async throws -> PosePoints3D?
}

// MARK: - Combined 2D+3D Detection Protocol

protocol BodyPoseDetectService {
    func detectBodyPose(from sampleBuffer: CMSampleBuffer) async throws -> BodyJoints?
}
