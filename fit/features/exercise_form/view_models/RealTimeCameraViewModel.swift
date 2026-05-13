import SwiftUI
import Combine
import AVFoundation
import Photos

// MARK: - Real-time 3D Pose Detection ViewModel

@available(iOS 17.0, *)
@MainActor
final class RealTimeCameraViewModel: ObservableObject {

    let cameraSession = CameraSession()
    private let frameProcessor = PoseFrameProcessor()
    private let controlQueue = DispatchQueue(label: "camera.control")

    @Published var detectedJoints: BodyJoints?
    @Published var isDetecting = false
    @Published var isFrontCamera = false
    @Published var jointNames: [String] = []
    @Published var errorMessage: String?
    @Published var recordedVideoURL: URL?

    func setupCamera() throws {
        controlQueue.sync {}
        try cameraSession.configure(position: .back)
        cameraSession.start()
    }

    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        do {
            try cameraSession.switchCamera(to: newPosition)
            isFrontCamera.toggle()
            if isDetecting {
                stopDetection()
                startDetection()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startDetection() {
        guard !isDetecting else { return }

        let fileName = "pose_\(Int(Date().timeIntervalSince1970)).mov"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
        frameProcessor.startRecording(to: fileURL, isFrontCamera: isFrontCamera)

        cameraSession.frameHandler = { [weak self] buffer in
            self?.frameProcessor.processFrame(buffer)
        }
        frameProcessor.onPoseDetected = { [weak self] joints in
            let names = joints.map(\.joint).sorted()
            self?.jointNames = names
            self?.detectedJoints = joints
        }
        frameProcessor.onPoseLost = { [weak self] in
            self?.detectedJoints = nil
            self?.jointNames = []
        }
        isDetecting = true
    }

    func stopDetection() {
        cameraSession.frameHandler = nil
        frameProcessor.onPoseDetected = nil
        frameProcessor.onPoseLost = nil
        isDetecting = false
        detectedJoints = nil
        jointNames = []

        if let url = frameProcessor.stopRecording() {
            saveAndShow(url: url)
        }
    }

    func stopCamera() {
        cameraSession.frameHandler = nil
        frameProcessor.onPoseDetected = nil
        frameProcessor.onPoseLost = nil
        isDetecting = false
        detectedJoints = nil
        jointNames = []

        if let url = frameProcessor.stopRecording() {
            saveAndShow(url: url)
        }

        controlQueue.async { [weak self] in
            self?.cameraSession.stop()
        }
    }

    private func saveAndShow(url: URL) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if status == .authorized || status == .limited {
                try? await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
            }
            await MainActor.run {
                self.recordedVideoURL = url
            }
        }
    }
}
