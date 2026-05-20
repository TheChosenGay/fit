import Foundation
import CoreMedia

/// 语音识别服务
protocol FitSpeechToTextService {
    /// 开始监听，识别到完整语句时回调
    func startListening(onUtterance: @escaping (String) -> Void) throws
    /// 追加音频 buffer
    func appendAudio(_ buffer: CMSampleBuffer)
    /// 结束当前识别会话
    func stopRecognition()
}
