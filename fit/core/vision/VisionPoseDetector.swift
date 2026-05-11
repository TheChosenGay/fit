//
//  VisionPoseDetector.swift
//  fit
//
//  Created by dai shan on 2026/5/9.
//

import Foundation
import Vision
import UIKit

class VisionPoseDetector {
    nonisolated static let detector = VisionPoseDetector()
    private init() {}
}


extension VisionPoseDetector: PoseDetectService {
    func detectPose(from image: UIImage) async throws -> PosePoints? {
        guard let cgImage = image.cgImage else {return nil}
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observation = request.results?.first as? VNHumanBodyPoseObservation else {
                    continuation.resume(returning: [])
                    return
                }
                
                do {
                    let allPoints = try observation.recognizedPoints(.all)
                    var posPoints: [PosePoint] = []
                    for (joint, point) in allPoints where point.confidence > 0.3 {
                        posPoints.append(
                            PosePoint(
                                joint: joint.rawValue.rawValue, location: point.location, confidence: point.confidence
                            )
                        )
                    }
                    continuation.resume(returning: posPoints)
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
