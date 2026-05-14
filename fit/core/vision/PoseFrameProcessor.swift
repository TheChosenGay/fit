import CoreMedia
import Foundation
import AVFoundation

// MARK: - Frame Processing Pipeline

@available(iOS 17.0, *)
final class PoseFrameProcessor: @unchecked Sendable {

    private let detector: BodyPoseDetectService
    private let processQueue = DispatchQueue(label: "pose.frame.processor", qos: .userInitiated)

    private var frameCount: Int = 0
    private let frameSkipInterval: Int = 4
    private var isProcessing = false

    var onPoseDetected: (@MainActor @Sendable (BodyJoints) -> Void)?
    var onPoseLost: (@MainActor @Sendable () -> Void)?

    init(backend: PoseDetectorBackend = .rtmPose) {
        switch backend {
        case .appleVision:
            self.detector = BodyPoseDetector.detector
        case .rtmPose:
            self.detector = RTMPoseDetector.detector
        }
    }

    // Recording
    private var recorder: PoseVideoRecorder?
    private var recorderURL: URL?
    private var isFrontCamera = false

    var isRecording: Bool { recorder?.isRecording ?? false }

    func startRecording(to url: URL, isFrontCamera: Bool) {
        self.recorderURL = url
        self.isFrontCamera = isFrontCamera
        self.recorder = PoseVideoRecorder()
    }

    func stopRecording() -> URL? {
        let rec = recorder
        recorder = nil
        let url = rec?.stop()
        recorderURL = nil
        return url
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        guard frameCount % frameSkipInterval == 0 else { return }

        let front = isFrontCamera
        let rec = recorder

        // Lazy-start recorder on first processed frame (get pixel buffer dimensions)
        if let rec, !rec.isRecording,
           let pb = CMSampleBufferGetImageBuffer(sampleBuffer),
           let url = recorderURL {
            let w = CVPixelBufferGetWidth(pb)
            let h = CVPixelBufferGetHeight(pb)
            if w > 0, h > 0 {
                do {
                    try rec.start(outputURL: url, width: w, height: h)
                } catch {
                    // Recording won't start; frames will be skipped
                }
            }
        }

        // Dispatch to serial queue so isProcessing reads/writes are safe
        processQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isProcessing else { return }
            self.isProcessing = true

            let buffer = sampleBuffer
            Task {
                defer { self.isProcessing = false }
                guard let joints = try? await self.detector.detectBodyPose(from: buffer) else {
                    await MainActor.run { self.onPoseLost?() }
                    return
                }
                // Composite frame for recording
                if let rec = self.recorder, rec.isRecording,
                   let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
                    rec.appendFrame(pixelBuffer: pixelBuffer, joints: joints, isFrontCamera: front)
                }
                await MainActor.run { self.onPoseDetected?(joints) }
            }
        }
    }
}
