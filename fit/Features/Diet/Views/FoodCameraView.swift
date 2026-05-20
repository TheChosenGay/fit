import SwiftUI
import Combine
import ARKit
import SwiftData

// MARK: - LiDAR camera preview (renders ARFrame.capturedImage)

private struct LiDARPreviewView: UIViewRepresentable {
    let arSession: ARSession

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .black

        let displayLink = CADisplayLink(
            target: context.coordinator,
            selector: #selector(Coordinator.tick)
        )
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 20, preferred: 15)
        displayLink.add(to: .main, forMode: .common)
        context.coordinator.displayLink = displayLink
        context.coordinator.imageView = imageView
        context.coordinator.arSession = arSession

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var displayLink: CADisplayLink?
        weak var imageView: UIImageView?
        var arSession: ARSession?
        private let ciContext = CIContext()

        @objc func tick() {
            guard let frame = arSession?.currentFrame,
                  let imageView = imageView else { return }
            let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
            imageView.image = UIImage(cgImage: cgImage)
        }
    }
}

// MARK: - FoodCameraView

@available(iOS 17.0, *)
struct FoodCameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = FoodCameraViewModel()

    let mealType: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.permissionGranted {
                cameraPreview
                captureOverlay
            } else {
                permissionPrompt
            }

            if vm.isAnalyzing {
                analyzingOverlay
            }
        }
        .task { await vm.checkPermission() }
        .onDisappear { vm.stopSession() }
        .sheet(isPresented: $vm.showVolumePicker) {
            FoodVolumePicker(foodItems: vm.volumePickerItems) { volumes in
                Task { await vm.onVolumePicked(volumes) }
            }
        }
        .onChange(of: vm.savedMeal) { meal in
            if meal != nil { dismiss() }
        }
        .alert("错误", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("确定") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Camera preview

    @ViewBuilder
    private var cameraPreview: some View {
        if vm.hasLiDAR {
            LiDARPreviewView(arSession: vm.arSession)
                .ignoresSafeArea()
        } else {
            CameraPreviewView(session: vm.cameraSession.session)
                .ignoresSafeArea()
        }
    }

    // MARK: - Capture overlay

    private var captureOverlay: some View {
        VStack {
            Spacer()

            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }

                Spacer()

                Text(vm.hasLiDAR ? "LiDAR 自动测量" : "拍摄食物")
                    .dsTextStyle(.body)
                    .foregroundColor(.white)

                Spacer()

                // Symmetry spacer
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.lg)

            // Capture button
            Button {
                Task { await vm.capture(mealType: mealType, context: modelContext) }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 66, height: 66)
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Analyzing overlay

    @ViewBuilder
    private var analyzingOverlay: some View {
        Color.black.opacity(0.5).ignoresSafeArea()
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("正在识别食物...")
                .dsTextStyle(.body)
                .foregroundColor(.white)
        }
    }

    // MARK: - Permission prompt

    private var permissionPrompt: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.6))
            Text("需要相机权限")
                .dsTextStyle(.headline)
                .foregroundColor(.white)
            Text("请在设置中开启相机权限以拍摄食物照片")
                .dsTextStyle(.body)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.xxl)
            Button("前往设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
            .tint(.dsPrimary)
        }
        .padding(DSSpacing.xxl)
    }
}
