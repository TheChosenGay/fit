import SwiftUI
import AVKit

// MARK: - Real-time 3D Pose Detection Camera View

@available(iOS 17.0, *)
struct RealTimeCameraView: View {
    @StateObject private var viewModel = RealTimeCameraViewModel()
    @State private var showPlayer = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // 摄像头预览
            CameraPreviewView(session: viewModel.cameraSession.session)
                .ignoresSafeArea()

            // 骨骼叠加（2D 归一化坐标，精准对齐）
            if viewModel.isDetecting, let joints = viewModel.detectedJoints, !joints.isEmpty {
                GeometryReader { geo in
                    Canvas { context, _ in
                        var ctx = context
                        Skeleton3DRenderer.draw(
                            context: &ctx,
                            joints: joints,
                            canvasSize: geo.size,
                            isFrontCamera: viewModel.isFrontCamera
                        )
                    }
                    .allowsHitTesting(false)
                }
            }

            // 顶部状态栏
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("3D 骨骼检测")
                            .font(.headline)
                            .foregroundColor(.white)

                        if viewModel.isDetecting {
                            if let joints = viewModel.detectedJoints {
                                let with3D = joints.filter { $0.position3D != nil }.count
                                Text("\(joints.count) 关节点 (3D: \(with3D))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("等待人体入镜...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        } else {
                            Text("点击下方按钮开始")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // 镜头翻转
                    Button(action: { viewModel.flipCamera() }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    // 连接状态
                    Circle()
                        .fill(viewModel.isDetecting
                            ? (viewModel.detectedJoints != nil ? Color.green : Color.yellow)
                            : Color.gray)
                        .frame(width: 10, height: 10)

                    // 关闭按钮
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // 查看录制按钮
                if let videoURL = viewModel.recordedVideoURL {
                    Button(action: { showPlayer = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle")
                            Text("查看录制")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    .padding(.bottom, 12)
                }

                // 开始/停止
                Button(action: {
                    if viewModel.isDetecting {
                        viewModel.stopDetection()
                    } else {
                        viewModel.startDetection()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isDetecting ? "stop.fill" : "play.fill")
                        Text(viewModel.isDetecting ? "停止检测" : "开始检测")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(viewModel.isDetecting ? Color.red : Color.green)
                    .cornerRadius(28)
                    .shadow(radius: 8)
                }
                .padding(.bottom, 48)
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let url = viewModel.recordedVideoURL {
                VideoPlayerView(url: url, isPresented: $showPlayer)
            }
        }
        .task {
            do {
                try viewModel.setupCamera()
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .onDisappear {
            viewModel.stopCamera()
        }
    }
}

// MARK: - Video Player

struct VideoPlayerView: View {
    let url: URL
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") { isPresented = false }
                            .foregroundColor(.white)
                    }
                }
        }
    }
}

// MARK: - Fallback for iOS < 17

struct RealTimeCameraFallbackView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("需要 iOS 17+")
                .font(.title2)
                .fontWeight(.semibold)
            Text("3D 实时骨骼检测需要 iOS 17 或更高版本。\n请升级系统后使用此功能。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Version-adaptive entry

struct RealTimeCameraEntryView: View {
    @State private var showCamera = false

    var body: some View {
        if #available(iOS 17.0, *) {
            VStack(spacing: 24) {
                Spacer()

                // 实时摄像头检测 — fullScreenCover 弹出，不和 NavigationStack 混用
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.dsPrimary)
                            .frame(width: 56, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                                    .fill(Color.dsPrimary.opacity(0.15))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("实时摄像头检测")
                                .dsTextStyle(.body)
                                .foregroundColor(.white)
                            Text("打开摄像头，实时检测并录制骨骼姿态")
                                .dsTextStyle(.caption1)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(DSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                            .fill(Color.white.opacity(0.08))
                    )
                }

                // 从视频分析 — NavigationLink 推入导航栈
                NavigationLink {
                    VideoAnalysisView()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.dsSuccess)
                            .frame(width: 56, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                                    .fill(Color.dsSuccess.opacity(0.15))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("从视频分析")
                                .dsTextStyle(.body)
                                .foregroundColor(.white)
                            Text("选择已有视频，逐帧检测骨骼并生成分析结果")
                                .dsTextStyle(.caption1)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(DSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                            .fill(Color.white.opacity(0.08))
                    )
                }

                Spacer()
            }
            .padding(.horizontal, DSSpacing.lg)
            .background(Color.dsBackground.ignoresSafeArea())
            .fullScreenCover(isPresented: $showCamera) {
                RealTimeCameraView()
            }
        } else {
            RealTimeCameraFallbackView()
        }
    }
}
