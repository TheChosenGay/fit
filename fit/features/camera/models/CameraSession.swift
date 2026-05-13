import AVFoundation
import UIKit

final class CameraSession: NSObject, @unchecked Sendable {

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    private let videoDataOutput = AVCaptureVideoDataOutput()
    var frameHandler: ((CMSampleBuffer) -> Void)?
    private let videoQueue = DispatchQueue(label: "camera.video.frames", qos: .userInitiated)

    private var currentPosition: AVCaptureDevice.Position = .back

    // MARK: - Setup

    func configure(position: AVCaptureDevice.Position = .back) throws {
        currentPosition = position
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            throw CameraError.deviceUnavailable
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            throw CameraError.cannotAddOutput
        }
        session.addOutput(photoOutput)

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
        }

        session.commitConfiguration()

        if let connection = videoDataOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    // MARK: - Camera Flip

    func switchCamera(to position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()

        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.deviceUnavailable
        }

        session.addInput(input)
        currentPosition = position
        session.commitConfiguration()

        if let connection = videoDataOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    // MARK: - Session Control

    func start() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    // MARK: - Photo Capture

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            photoContinuation?.resume(throwing: error)
            photoContinuation = nil
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(throwing: CameraError.captureDataInvalid)
            photoContinuation = nil
            return
        }
        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameHandler?(sampleBuffer)
    }
}

enum CameraError: Error, LocalizedError {
    case deviceUnavailable
    case cannotAddInput
    case cannotAddOutput
    case captureDataInvalid
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable: return "相机设备不可用"
        case .cannotAddInput: return "无法添加相机输入"
        case .cannotAddOutput: return "无法添加照片输出"
        case .captureDataInvalid: return "照片数据无效"
        case .permissionDenied: return "相机或相册权限被拒绝，请在设置中开启"
        }
    }
}
