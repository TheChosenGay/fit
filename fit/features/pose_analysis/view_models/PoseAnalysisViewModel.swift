import Combine
import SwiftUI

@MainActor
final class PoseAnalysisViewModel: ObservableObject {
    let image: UIImage
    let poseDetector: PoseDetectService
    let analysisService: PoseAnalysisService

    @Published var phase: AnalysisPhase = .detecting
    @Published var annotatedImage: UIImage?
    @Published var angles: PoseAngle?
    @Published var report: AnalysisReport?
    @Published var error: String?

    enum AnalysisPhase {
        case detecting
        case analyzing
        case done
        case error
    }

    init(
        image: UIImage,
        poseDetector: PoseDetectService = VisionPoseDetector.detector,
        analysisService: PoseAnalysisService = AIAnalysisService.shared
    ) {
        self.image = image
        self.poseDetector = poseDetector
        self.analysisService = analysisService
    }

    func startAnalysis() async {
        phase = .detecting
        error = nil
        await Task.yield()

        do {
            guard let points = try await poseDetector.detectPose(from: image), !points.isEmpty else {
                phase = .error
                error = "未检测到人体姿态，请确保照片中包含完整站立人物"
                return
            }

            angles = AngleCalculator.compute(points)
            annotatedImage = SkeletonRenderer.render(image: image, points: points)

            phase = .analyzing
            if let angles {
                do {
                    report = try await analysisService.analyze(angles: angles)
                } catch {
                    report = nil
                }
            }

            phase = .done
        } catch let e {
            phase = .error
            error = "姿态检测失败：\(e.localizedDescription)"
        }
    }
}
