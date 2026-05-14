import SwiftUI

// MARK: - CameraView
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showPhotoPicker = false
    @State private var showPreview = false
    @State private var showAnalysis = false
    @State private var analysisImage: UIImage?

    var body: some View {
        ZStack {
            if viewModel.permissionGranted {
                cameraContent
            } else {
                permissionDeniedView
            }
        }
        .task { await viewModel.checkAndRequestPermission() }
        .onDisappear { viewModel.stopSession() }
        .onChange(of: viewModel.capturedImage) { image in
            if image != nil { showPreview = true }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView { image in
                viewModel.handlePickedPhoto(image)
            }
        }
        .navigationDestination(isPresented: $showPreview) {
            if let image = viewModel.capturedImage {
                PhotoPreviewView(
                    image: image,
                    onConfirm: {
                        analysisImage = image
                    },
                    onRetake: {
                        viewModel.capturedImage = nil
                        viewModel.lastSavedFileName = nil
                        analysisImage = nil
                    }
                )
                .navigationBarHidden(true)
            }
        }
        .onChange(of: showPreview) { isPresented in
            if !isPresented, analysisImage != nil {
                showAnalysis = true
            }
        }
        .navigationDestination(isPresented: $showAnalysis) {
            if let image = analysisImage {
                if #available(iOS 17.0, *) {
                    PoseAnalysisView(image: image)
                }
            }
        }
        .onChange(of: showAnalysis) { isPresented in
            if !isPresented { analysisImage = nil }
        }
        .alert("相机错误", isPresented: .constant(viewModel.error != nil)) {
            Button("确定") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }

    // MARK: - 相机预览 + 控制栏
    private var cameraContent: some View {
        VStack(spacing: 0) {
            ZStack {
                CameraPreviewView(session: viewModel.cameraSession.session)
                    .ignoresSafeArea()
                PoseGuideOverlay()
            }

            shutterBar
                .background(Color.black)
        }
    }

    // MARK: - 底部控制栏
    private var shutterBar: some View {
        HStack {
            Button {
                showPhotoPicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
            }

            Spacer()

            Button {
                Task { await viewModel.capturePhoto() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .opacity(viewModel.isCapturing ? 0.5 : 1)
                }
            }
            .disabled(viewModel.isCapturing)

            Spacer()

            Color.clear.frame(width: 60, height: 60)
        }
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.vertical, DSSpacing.xl)
    }

    // MARK: - 权限被拒
    private var permissionDeniedView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.dsLabelSecondary)
            Text("需要相机权限")
                .dsTextStyle(.headline)
            Text("请前往「设置 → PostureAI → 相机」开启权限")
                .dsTextStyle(.body)
                .foregroundColor(.dsLabelSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.xxl)
            Button("前往设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - PoseGuideOverlay
private struct PoseGuideOverlay: View {
    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let strokeStyle = StrokeStyle(lineWidth: 1.5, dash: [8, 6])
            var path = Path()

            path.move(to: CGPoint(x: cx, y: size.height * 0.05))
            path.addLine(to: CGPoint(x: cx, y: size.height * 0.95))

            let shoulderY = size.height * 0.28
            path.move(to: CGPoint(x: cx - size.width * 0.22, y: shoulderY))
            path.addLine(to: CGPoint(x: cx + size.width * 0.22, y: shoulderY))

            let hipY = size.height * 0.55
            path.move(to: CGPoint(x: cx - size.width * 0.16, y: hipY))
            path.addLine(to: CGPoint(x: cx + size.width * 0.16, y: hipY))

            context.stroke(path, with: .color(.white.opacity(0.5)), style: strokeStyle)
        }
    }
}
