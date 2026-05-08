import AVFoundation
import UIKit

// MARK: - CameraSession
// 封装 AVFoundation 相机核心逻辑：Session 配置、启动/停止、拍照
// 标记为 @unchecked Sendable，AVCaptureSession 内部自己保证线程安全
final class CameraSession: NSObject, @unchecked Sendable {

    // 对外暴露的 session，供预览层绑定
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    // MARK: - Setup

    /// 配置相机输入输出
    func configure() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
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

        session.commitConfiguration()
    }

    // MARK: - Session 控制

    func start() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    // MARK: - 拍照

    /// 拍照，async 返回 UIImage
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

// MARK: - CameraError
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
        case .permissionDenied: return "相机权限被拒绝，请在设置中开启"
        }
    }
}
