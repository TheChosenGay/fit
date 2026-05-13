import Vision
import CoreMedia

// MARK: - Combined 2D + 3D Body Pose Detector (iOS 17+)

@available(iOS 17.0, *)
final class BodyPoseDetector: BodyPoseDetectService {

    nonisolated static let detector = BodyPoseDetector()

    private let request2D = VNDetectHumanBodyPoseRequest()
    private let request3D = VNDetectHumanBodyPose3DRequest()

    private init() {}

    // Canonical joint names used throughout the app
    static let canonicalNames: Set<String> = [
        "nose", "left_eye_joint", "right_eye_joint",
        "left_ear_joint", "right_ear_joint",
        "neck_1_joint", "root",
        "left_shoulder_1_joint", "right_shoulder_1_joint",
        "left_forearm_joint", "right_forearm_joint",
        "left_hand_joint", "right_hand_joint",
        "left_upLeg_joint", "right_upLeg_joint",
        "left_leg_joint", "right_leg_joint",
        "left_foot_joint", "right_foot_joint",
    ]

    /// Map ANY Vision output name (2D or 3D) to canonical form.
    /// Handles: 2D String(describing: VNRecognizedPointKey) → e.g. "neck", "left_shoulder", "left_elbow", "left_wrist", ...
    /// Handles: 3D point.identifier.rawValue → e.g. "neck_1_joint", "left_forearm_joint", "left_hand_joint", ...
    static func canonicalJointName(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)

        // Direct match with canonical names
        if canonicalNames.contains(raw) { return raw }
        if canonicalNames.contains(lower) { return lower }

        // Comprehensive mapping: keyword → canonical 3D name
        let map: [(String, String)] = [
            // Head / face
            ("nose", "nose"),
            ("left_eye", "left_eye_joint"), ("lefteye", "left_eye_joint"),
            ("right_eye", "right_eye_joint"), ("righteye", "right_eye_joint"),
            ("left_ear", "left_ear_joint"), ("leftear", "left_ear_joint"),
            ("right_ear", "right_ear_joint"), ("rightear", "right_ear_joint"),

            // Neck / head
            ("neck_1", "neck_1_joint"), ("neck1", "neck_1_joint"),
            ("neck_2", "neck_1_joint"), ("neck2", "neck_1_joint"),
            ("neck_3", "neck_1_joint"), ("neck3", "neck_1_joint"),
            ("neck_4", "neck_1_joint"), ("neck4", "neck_1_joint"),
            ("neck", "neck_1_joint"), ("head", "neck_1_joint"),

            // Root
            ("root", "root"),

            // Left shoulder
            ("left_shoulder_1", "left_shoulder_1_joint"), ("leftshoulder_1", "left_shoulder_1_joint"),
            ("left_shoulder_2", "left_shoulder_1_joint"),
            ("left_shoulder", "left_shoulder_1_joint"), ("leftshoulder", "left_shoulder_1_joint"),

            // Right shoulder
            ("right_shoulder_1", "right_shoulder_1_joint"), ("rightshoulder_1", "right_shoulder_1_joint"),
            ("right_shoulder_2", "right_shoulder_1_joint"),
            ("right_shoulder", "right_shoulder_1_joint"), ("rightshoulder", "right_shoulder_1_joint"),

            // Left arm
            ("left_elbow", "left_forearm_joint"), ("leftelbow", "left_forearm_joint"),
            ("left_forearm", "left_forearm_joint"), ("leftforearm", "left_forearm_joint"),
            ("left_wrist", "left_hand_joint"), ("leftwrist", "left_hand_joint"),
            ("left_hand", "left_hand_joint"), ("lefthand", "left_hand_joint"),

            // Right arm
            ("right_elbow", "right_forearm_joint"), ("rightelbow", "right_forearm_joint"),
            ("right_forearm", "right_forearm_joint"), ("rightforearm", "right_forearm_joint"),
            ("right_wrist", "right_hand_joint"), ("rightwrist", "right_hand_joint"),
            ("right_hand", "right_hand_joint"), ("righthand", "right_hand_joint"),

            // Left leg
            ("left_hip", "left_upLeg_joint"), ("lefthip", "left_upLeg_joint"),
            ("left_upleg", "left_upLeg_joint"), ("leftupleg", "left_upLeg_joint"),
            ("left_knee", "left_leg_joint"), ("leftknee", "left_leg_joint"),
            ("left_leg", "left_leg_joint"), ("leftleg", "left_leg_joint"),
            ("left_ankle", "left_foot_joint"), ("leftankle", "left_foot_joint"),
            ("left_foot", "left_foot_joint"), ("leftfoot", "left_foot_joint"),

            // Right leg
            ("right_hip", "right_upLeg_joint"), ("righthip", "right_upLeg_joint"),
            ("right_upleg", "right_upLeg_joint"), ("rightupleg", "right_upLeg_joint"),
            ("right_knee", "right_leg_joint"), ("rightknee", "right_leg_joint"),
            ("right_leg", "right_leg_joint"), ("rightleg", "right_leg_joint"),
            ("right_ankle", "right_foot_joint"), ("rightankle", "right_foot_joint"),
            ("right_foot", "right_foot_joint"), ("rightfoot", "right_foot_joint"),
        ]
        for (kw, canonical) in map where lower.contains(kw) { return canonical }
        return raw
    }

    func detectBodyPose(from sampleBuffer: CMSampleBuffer) async throws -> BodyJoints? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        // Pixel buffer is already rotated to portrait by AVCaptureConnection.videoOrientation
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try handler.perform([request2D, request3D])

        // --- 2D results ---
        var joints2D: [String: (location: CGPoint, confidence: Float)] = [:]
        if let obs2D = request2D.results?.first,
           let pts2D = try? obs2D.recognizedPoints(.all) {
            for (key, point) in pts2D {
                guard point.confidence > 0.3 else { continue }
                let canonical = Self.canonicalJointName(String(describing: key))
                joints2D[canonical] = (point.location, point.confidence)
            }
        }

        // --- 3D results ---
        var joints3D: [String: simd_float3] = [:]
        if let obs3D = request3D.results?.first {
            for jointName in obs3D.availableJointNames {
                guard let point = try? obs3D.recognizedPoint(jointName) else { continue }
                let t = point.position
                let pos = simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
                let canonical = Self.canonicalJointName(point.identifier.rawValue)
                joints3D[canonical] = pos
            }
        }

        // --- Merge by canonical name ---
        let allKeys = Set(joints2D.keys).union(joints3D.keys)
        guard !allKeys.isEmpty else { return nil }

        var result = BodyJoints()
        for key in allKeys.sorted() {
            let loc2D = joints2D[key]?.location
            let pos3D = joints3D[key]
            let conf = joints2D[key]?.confidence ?? 0.5

            result.append(BodyJoint(
                joint: key,
                location2D: loc2D ?? .zero,
                position3D: pos3D,
                confidence: conf
            ))
        }

        return result.isEmpty ? nil : result
    }
}
