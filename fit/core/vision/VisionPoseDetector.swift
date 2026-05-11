import Foundation
import Vision
import UIKit

final class VisionPoseDetector {
    nonisolated static let detector = VisionPoseDetector()
    private init() {}
}

extension VisionPoseDetector: PoseDetectService {
    func detectPose(from image: UIImage) async throws -> PosePoints? {
        guard let cgImage = image.cgImage else {
            print("[VisionPoseDetector] ❌ image.cgImage 为 nil，图片尺寸: \(image.size)")
            return nil
        }

        print("[VisionPoseDetector] 📷 开始检测，图片尺寸: \(image.size)")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                if let error {
                    print("[VisionPoseDetector] ❌ Vision 错误: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let observation = request.results?.first as? VNHumanBodyPoseObservation else {
                    print("[VisionPoseDetector] ⚠️ 未识别到人体，results 数量: \(request.results?.count ?? 0)")
                    continuation.resume(returning: [])
                    return
                }

                do {
                    let allPoints = try observation.recognizedPoints(.all)
                    print("[VisionPoseDetector] 🔍 识别到 \(allPoints.count) 个关节点:")

                    var posPoints: [PosePoint] = []
                    for (joint, point) in allPoints {
                        let isAboveThreshold = point.confidence > 0.5
                        let marker = isAboveThreshold ? "✅" : "⬜"
                        print("[VisionPoseDetector]   \(marker) \(joint.rawValue.rawValue): conf=\(String(format: "%.2f", point.confidence))")

                        if isAboveThreshold {
                            posPoints.append(
                                PosePoint(
                                    joint: joint.rawValue.rawValue,
                                    location: point.location,
                                    confidence: point.confidence
                                )
                            )
                        }
                    }

                    print("[VisionPoseDetector] 📊 高于阈值(0.5)的节点: \(posPoints.count)/\(allPoints.count)")
                    continuation.resume(returning: posPoints)
                } catch {
                    print("[VisionPoseDetector] ❌ recognizedPoints 错误: \(error)")
                    continuation.resume(throwing: error)
                }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[VisionPoseDetector] ❌ perform 错误: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
}
