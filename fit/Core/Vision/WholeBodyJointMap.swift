import Foundation

// COCO-WholeBody 133 keypoints: body 17 + feet 6 + face 68 + left hand 21 + right hand 21

enum WholeBodyJointMap {

    static let names: [String] = {
        var n = [String]()
        // Body (0-16)
        n.append(contentsOf: [
            "nose",
            "left_eye", "right_eye",
            "left_ear", "right_ear",
            "left_shoulder", "right_shoulder",
            "left_elbow", "right_elbow",
            "left_wrist", "right_wrist",
            "left_hip", "right_hip",
            "left_knee", "right_knee",
            "left_ankle", "right_ankle",
        ])
        // Feet (17-22)
        n.append(contentsOf: [
            "left_big_toe", "left_small_toe", "left_heel",
            "right_big_toe", "right_small_toe", "right_heel",
        ])
        // Face (23-90)
        for i in 0..<68 { n.append("face_\(i)") }
        // Left hand (91-111)
        let fingerNames = ["thumb", "index", "middle", "ring", "pinky"]
        n.append("left_hand_wrist")
        for finger in fingerNames {
            for j in 1...4 { n.append("left_\(finger)_\(j)") }
        }
        // Right hand (112-132)
        n.append("right_hand_wrist")
        for finger in fingerNames {
            for j in 1...4 { n.append("right_\(finger)_\(j)") }
        }
        assert(n.count == 133)
        return n
    }()

    static func canonicalName(for index: Int) -> String {
        guard index >= 0, index < names.count else { return "unknown_\(index)" }
        return names[index]
    }

    // MARK: - Legacy 19-joint mapping

    static let legacyMapping: [String: String] = [
        "nose": "nose",
        "left_eye": "left_eye_joint",
        "right_eye": "right_eye_joint",
        "left_ear": "left_ear_joint",
        "right_ear": "right_ear_joint",
        "left_shoulder": "left_shoulder_1_joint",
        "right_shoulder": "right_shoulder_1_joint",
        "left_elbow": "left_forearm_joint",
        "right_elbow": "right_forearm_joint",
        "left_wrist": "left_hand_joint",
        "right_wrist": "right_hand_joint",
        "left_hip": "left_upLeg_joint",
        "right_hip": "right_upLeg_joint",
        "left_knee": "left_leg_joint",
        "right_knee": "right_leg_joint",
        "left_ankle": "left_foot_joint",
        "right_ankle": "right_foot_joint",
    ]

    static func filterToLegacyBody(_ joints: BodyJoints) -> BodyJoints {
        let dict = Dictionary(joints.map { ($0.joint, $0) }, uniquingKeysWith: { a, _ in a })
        var result = BodyJoints()

        for (extendedName, legacyName) in legacyMapping {
            guard let j = dict[extendedName] else { continue }
            result.append(BodyJoint(
                joint: legacyName,
                location2D: j.location2D,
                position3D: j.position3D,
                confidence: j.confidence
            ))
        }

        // Synthesize neck_1_joint = midpoint of shoulders
        if let ls = dict["left_shoulder"], let rs = dict["right_shoulder"] {
            result.append(BodyJoint(
                joint: "neck_1_joint",
                location2D: CGPoint(
                    x: (ls.location2D.x + rs.location2D.x) / 2,
                    y: (ls.location2D.y + rs.location2D.y) / 2
                ),
                position3D: nil,
                confidence: min(ls.confidence, rs.confidence)
            ))
        }

        // Synthesize root = midpoint of hips
        if let lh = dict["left_hip"], let rh = dict["right_hip"] {
            result.append(BodyJoint(
                joint: "root",
                location2D: CGPoint(
                    x: (lh.location2D.x + rh.location2D.x) / 2,
                    y: (lh.location2D.y + rh.location2D.y) / 2
                ),
                position3D: nil,
                confidence: min(lh.confidence, rh.confidence)
            ))
        }

        return result.sorted { $0.joint < $1.joint }
    }

    // Convert extended joints to legacy PosePoints (for static image analysis path)
    static func filterToLegacyPosePoints(_ joints: BodyJoints) -> PosePoints {
        filterToLegacyBody(joints).map {
            PosePoint(joint: $0.joint, location: $0.location2D, confidence: $0.confidence)
        }
    }

    // MARK: - Renderable mapping (body legacy + feet + hands, skip face)

    private static let faceRange = 23...90

    static func mapToRenderable(_ joints: BodyJoints) -> BodyJoints {
        let dict = Dictionary(joints.map { ($0.joint, $0) }, uniquingKeysWith: { a, _ in a })
        var result = BodyJoints()

        // Body 17 → legacy names
        for (extendedName, legacyName) in legacyMapping {
            guard let j = dict[extendedName] else { continue }
            result.append(BodyJoint(
                joint: legacyName,
                location2D: j.location2D,
                position3D: j.position3D,
                confidence: j.confidence
            ))
        }

        // Synthesize neck_1_joint
        if let ls = dict["left_shoulder"], let rs = dict["right_shoulder"] {
            result.append(BodyJoint(
                joint: "neck_1_joint",
                location2D: CGPoint(
                    x: (ls.location2D.x + rs.location2D.x) / 2,
                    y: (ls.location2D.y + rs.location2D.y) / 2
                ),
                position3D: nil,
                confidence: min(ls.confidence, rs.confidence)
            ))
        }

        // Synthesize root
        if let lh = dict["left_hip"], let rh = dict["right_hip"] {
            result.append(BodyJoint(
                joint: "root",
                location2D: CGPoint(
                    x: (lh.location2D.x + rh.location2D.x) / 2,
                    y: (lh.location2D.y + rh.location2D.y) / 2
                ),
                position3D: nil,
                confidence: min(lh.confidence, rh.confidence)
            ))
        }

        // Feet + Hands: keep canonical names, skip face (indices 23-90)
        for j in joints {
            guard let idx = names.firstIndex(of: j.joint) else { continue }
            if idx >= 17 && !faceRange.contains(idx) {
                result.append(j)
            }
        }

        return result
    }

    static func filterToRenderablePosePoints(_ joints: BodyJoints) -> PosePoints {
        mapToRenderable(joints).map {
            PosePoint(joint: $0.joint, location: $0.location2D, confidence: $0.confidence)
        }
    }
}
