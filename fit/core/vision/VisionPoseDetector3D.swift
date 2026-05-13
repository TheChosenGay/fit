import Vision
import CoreMedia

// MARK: - 3D Body Pose Detector (iOS 17+)

@available(iOS 17.0, *)
final class VisionPoseDetector3D: PoseDetectService3D {

    nonisolated static let detector = VisionPoseDetector3D()

    private let request = VNDetectHumanBodyPose3DRequest()

    private init() {}

    func detectPose3D(from sampleBuffer: CMSampleBuffer) async throws -> PosePoints3D? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return nil
        }

        var points = PosePoints3D()
        for jointName in observation.availableJointNames {
            guard let point = try? observation.recognizedPoint(jointName) else { continue }

            let transform = point.position  // simd_float4x4
            let localPos = simd_float3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            let posePoint = PosePoint3D(
                joint: point.identifier.rawValue,
                position: localPos,
                positionConfidence: 1.0,
                confidence: 1.0,
                location2D: .zero
            )
            points.append(posePoint)
        }

        return points.isEmpty ? nil : points
    }
}
