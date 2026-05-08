import Vision
import UIKit

// MARK: - PosePoint
struct PosePoint {
    let joint: VNHumanBodyPoseObservation.JointName
    let location: CGPoint   // 归一化坐标 (0-1)
    let confidence: Float
}

// MARK: - PoseDetectionResult
struct PoseDetectionResult {
    let points: [VNHumanBodyPoseObservation.JointName: PosePoint]

    func point(_ joint: VNHumanBodyPoseObservation.JointName) -> PosePoint? {
        points[joint]
    }
}

// MARK: - VisionPoseDetector
final class VisionPoseDetector {
    static let shared = VisionPoseDetector()
    private init() {}

    /// 对静态图片执行姿态检测
    func detect(image: UIImage) async throws -> PoseDetectionResult? {
        guard let cgImage = image.cgImage else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observation = request.results?.first as? VNHumanBodyPoseObservation else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    let allPoints = try observation.recognizedPoints(.all)
                    var posePoints: [VNHumanBodyPoseObservation.JointName: PosePoint] = [:]
                    for (joint, point) in allPoints where point.confidence > 0.3 {
                        posePoints[joint] = PosePoint(
                            joint: joint,
                            location: point.location,
                            confidence: point.confidence
                        )
                    }
                    continuation.resume(returning: PoseDetectionResult(points: posePoints))
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
