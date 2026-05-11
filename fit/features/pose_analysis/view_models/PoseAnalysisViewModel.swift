import Combine
import SwiftUI

@MainActor
final class PoseAnalysisViewModel: ObservableObject {
    let image: UIImage
    let poseDetector: PoseDetectService
    let textAnalysisService: PoseAnalysisService
    let multimodalService: MultimodalAnalysisService
    var aiModel: AIModel

    @Published var phase: AnalysisPhase = .detecting
    @Published var annotatedImage: UIImage?
    @Published var edgeCompositeImage: UIImage?
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
        aiModel: AIModel = .deepseek,
        poseDetector: PoseDetectService = VisionPoseDetector.detector,
        textAnalysisService: PoseAnalysisService = AIAnalysisService.shared,
        multimodalService: MultimodalAnalysisService = ZhipuVisionService.shared
    ) {
        self.image = image
        self.aiModel = aiModel
        self.poseDetector = poseDetector
        self.textAnalysisService = textAnalysisService
        self.multimodalService = multimodalService
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

            let cgSize = image.cgImage.map { CGSize(width: $0.width, height: $0.height) } ?? image.size
            let result = AngleCalculator.compute(points, cgImageSize: cgSize)
            angles = result.angle
            annotatedImage = SkeletonRenderer.render(image: image, points: points)

            // 多模态模型：生成人像分割+骨骼合成图
            if aiModel == .zhipu || aiModel == .minimax {
                edgeCompositeImage = EdgeDetector.composite(image: image, points: points)
            }

            phase = .analyzing
            if let angles {
                do {
                    report = try await analyze(angles: angles, points: points)
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

    private func analyze(angles: PoseAngle, points: [PosePoint]) async throws -> AnalysisReport {
        switch aiModel {
        case .deepseek:
            return try await textAnalysisService.analyze(angles: angles)
        case .zhipu:
            let compositeImage = edgeCompositeImage
                ?? EdgeDetector.composite(image: image, points: points)
                ?? image
            return try await ZhipuVisionService.shared.analyze(image: compositeImage, angles: angles)
        case .minimax:
            let compositeImage = edgeCompositeImage
                ?? EdgeDetector.composite(image: image, points: points)
                ?? image
            return try await MiniMaxVisionService.shared.analyze(image: compositeImage, angles: angles)
        }
    }
}
