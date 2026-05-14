import Foundation

protocol PoseAnalysisService {
    func analyze(angles: PoseAngle) async throws -> AnalysisReport
}
