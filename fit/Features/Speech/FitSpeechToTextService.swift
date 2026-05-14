import Foundation
import CoreMedia

/// 语音识别服务
protocol FitSpeechToTextService {
    /// 流式追加音频 buffer，返回当前最佳识别文本
    func speechToText(from buffer: CMSampleBuffer) async throws -> String?
    /// 结束当前识别会话
    func stopRecognition()
}
