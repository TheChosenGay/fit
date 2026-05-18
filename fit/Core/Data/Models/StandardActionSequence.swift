import Foundation

// MARK: - Standard Action Sequence (JSON wire format)

struct StandardActionSequence: Codable {
    let id: String
    let version: Int
    let metadata: SequenceMetadata
    let config: SequenceConfig
    let frames: [SequenceFrame]
}

struct SequenceMetadata: Codable {
    let exerciseName: String
    let exerciseId: String
    let author: String
    let createdAt: Date
    let description: String
    let difficulty: String
    let durationMs: Int
    let sourceVideoHash: String?
    let tags: [String]
}

struct SequenceConfig: Codable {
    let fps: Int
    let jointSet: String
    let coordinateSpace: String
    let rootJoint: String
    let isLoopable: Bool
    let phaseMarkers: [PhaseMarker]
    let criticalJoints: [String]
    let toleranceProfile: ToleranceProfile
}

struct PhaseMarker: Codable {
    let timeMs: Int
    let phase: String
}

struct ToleranceProfile: Codable {
    let global: Float
    let jointOverrides: [String: Float]?
}

struct SequenceFrame: Codable {
    let timeMs: Int
    let joints: [String: JointPosition3D]
}

struct JointPosition3D: Codable {
    let x: Float
    let y: Float
    let z: Float
}
