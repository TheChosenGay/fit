import SwiftUI
import Combine
import AVFoundation
import ARKit
import SwiftData

// MARK: - ARFrame handler (forwards ARSession updates to ViewModel)

private final class ARFrameHandler: NSObject, ARSessionDelegate {
    var onFrame: ((ARFrame) -> Void)?
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        onFrame?(frame)
    }
}

// MARK: - FoodCameraViewModel

@available(iOS 17.0, *)
@MainActor
final class FoodCameraViewModel: ObservableObject {
    @Published var permissionGranted = false
    @Published var errorMessage: String?
    @Published var isAnalyzing = false
    @Published var savedMeal: MealRecord?
    @Published var capturedImage: UIImage?
    @Published var showVolumePicker = false

    // Camera (non-LiDAR)
    let cameraSession = CameraSession()

    // LiDAR
    let arSession = ARSession()
    private let arFrameHandler = ARFrameHandler()
    private(set) var latestARFrame: ARFrame?

    var hasLiDAR: Bool { FoodVolumeEstimator.hasLiDAR }
    var volumePickerItems: [String] = []

    private let analysisService: DietAnalysisService = MiniMaxDietAnalysisService.shared

    // Pending analysis state
    private var pendingResult: MealAnalysisResult?
    private var pendingImage: UIImage?
    private var pendingMealType = ""
    private var pendingContext: ModelContext?
    private var pendingInstances: [FoodInstance]?

    // MARK: - Permission & Setup

    func checkPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionGranted = true
            setupCapture()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionGranted = granted
            if granted { setupCapture() }
        default:
            permissionGranted = false
            errorMessage = "请在设置中开启相机权限"
        }
    }

    private func setupCapture() {
        if hasLiDAR {
            arFrameHandler.onFrame = { [weak self] frame in
                Task { @MainActor in self?.latestARFrame = frame }
            }
            arSession.delegate = arFrameHandler
            let config = ARWorldTrackingConfiguration()
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                config.sceneReconstruction = .mesh
            }
            arSession.run(config)
        } else {
            guard cameraSession.session.inputs.isEmpty else {
                cameraSession.start()
                return
            }
            do {
                try cameraSession.configure()
                cameraSession.start()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Capture

    func capture(mealType: String, context: ModelContext) async {
        pendingMealType = mealType
        pendingContext = context
        errorMessage = nil
        savedMeal = nil

        let image: UIImage?
        if hasLiDAR {
            image = captureFromLiDAR()
        } else {
            image = try? await cameraSession.capturePhoto()
        }

        guard let image else {
            errorMessage = "拍摄失败，请重试"
            return
        }

        capturedImage = image
        await analyzePhoto(image)
    }

    private func captureFromLiDAR() -> UIImage? {
        guard let frame = latestARFrame else { return nil }

        // Start per-instance volume estimation in background while we convert the image
        Task.detached {
            let instances = await FoodVolumeEstimator.estimateVolumes(from: frame)
            await MainActor.run { self.pendingInstances = instances }
        }

        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - AI Analysis

    private func analyzePhoto(_ image: UIImage) async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let result = try await analysisService.analyze(image: image)
            pendingResult = result
            pendingImage = image

            if hasLiDAR {
                if let instances = pendingInstances,
                   let items = result.itemBreakdown, !items.isEmpty {
                    let volumeML = FoodVolumeEstimator.matchVolumes(instances: instances, to: items)
                    await finishSaving(volumeML)
                } else {
                    await finishSaving(nil)
                }
            } else {
                volumePickerItems = result.foodItems
                showVolumePicker = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Volume (non-LiDAR path)

    func onVolumePicked(_ volumes: [String: Float]) async {
        showVolumePicker = false
        await finishSaving(volumes)
    }

    func skipVolume() async {
        showVolumePicker = false
        await finishSaving(nil)
    }

    // MARK: - Save

    private func finishSaving(_ volumeML: [String: Float]?) async {
        guard let result = pendingResult,
              let image = pendingImage,
              let context = pendingContext else { return }

        do {
            let vm = DietViewModel()
            savedMeal = try await vm.saveAnalyzedMeal(
                result: result,
                image: image,
                mealType: pendingMealType,
                volumeML: volumeML,
                context: context
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Cleanup

    func stopSession() {
        cameraSession.stop()
        if hasLiDAR { arSession.pause() }
    }
}
