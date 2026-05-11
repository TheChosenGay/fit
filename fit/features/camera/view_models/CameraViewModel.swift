import AVFoundation
import Combine
import UIKit

// MARK: - CameraViewModel
@MainActor
final class CameraViewModel: ObservableObject {
    @Published var permissionGranted = false
    @Published var capturedImage: UIImage?
    @Published var lastSavedFileName: String?
    @Published var error: CameraError?
    @Published var isCapturing = false

    let cameraSession = CameraSession()
    private let photoStorage: PhotoStorageService = LocalPhotoStorageService()

    // MARK: - 权限

    func checkAndRequestPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            await setupSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionGranted = granted
            if granted { await setupSession() }
        default:
            permissionGranted = false
            error = .permissionDenied
        }
    }

    // MARK: - Session

    private func setupSession() async {
        // 已配置过则直接重启，避免重复 addInput 报错
        guard cameraSession.session.inputs.isEmpty else {
            cameraSession.start()
            return
        }
        do {
            try cameraSession.configure()
            cameraSession.start()
        } catch {
            self.error = error as? CameraError ?? .deviceUnavailable
        }
    }

    func stopSession() {
        cameraSession.stop()
    }

    // MARK: - 拍照

    func capturePhoto() async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let image = try await cameraSession.capturePhoto()
            await savePhoto(image)
        } catch {
            self.error = error as? CameraError ?? .captureDataInvalid
        }
    }

    /// 相册选择后调用
    func handlePickedPhoto(_ image: UIImage) {
        Task { await savePhoto(image) }
    }

    // MARK: - 存储

    private func savePhoto(_ image: UIImage) async {
        do {
            let fileName = try photoStorage.save(image: image)
            capturedImage = image
            lastSavedFileName = fileName
        } catch {
            self.error = .captureDataInvalid
        }
    }
}
