import SwiftUI
import AVKit

@available(iOS 17.0, *)
struct VideoAnalysisView: View {
    @StateObject private var viewModel = VideoAnalysisViewModel()
    @State private var showPicker = false
    @State private var showPlayer = false
    @State private var selectedURL: URL?
    @State private var videoDuration: String?
    @State private var videoResolution: String?
    @State private var frameInterval: Int = 4

    private let frameOptions: [(label: String, value: Int)] = [
        ("每帧", 1), ("每2帧", 2), ("每4帧", 4), ("每8帧", 8),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("从视频分析姿态")
                    .dsTextStyle(.title2)
                    .foregroundColor(.white)

                // Video selector / info
                if let url = selectedURL {
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.dsPrimary)

                        Text(url.lastPathComponent)
                            .dsTextStyle(.caption1)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)

                        if let dur = videoDuration {
                            Text("时长: \(dur)")
                                .dsTextStyle(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        if let res = videoResolution {
                            Text("分辨率: \(res)")
                                .dsTextStyle(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(DSSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.small)
                            .fill(Color.white.opacity(0.1))
                    )
                }

                Button(action: { showPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedURL == nil ? "plus.rectangle" : "arrow.triangle.2.circlepath")
                        Text(selectedURL == nil ? "选择视频" : "更换视频")
                    }
                    .dsTextStyle(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.vertical, DSSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.small)
                            .fill(Color.dsSecondary)
                    )
                }
                .disabled(viewModel.state == .processing)

                // Process status
                switch viewModel.state {
                case .idle:
                    if selectedURL != nil {
                        // Frame sampling control
                        VStack(spacing: 8) {
                            Text("帧采样间隔")
                                .dsTextStyle(.caption1)
                                .foregroundColor(.white.opacity(0.6))

                            HStack(spacing: 0) {
                                ForEach(frameOptions, id: \.value) { option in
                                    Button(action: { frameInterval = option.value }) {
                                        Text(option.label)
                                            .dsTextStyle(.caption1)
                                            .fontWeight(frameInterval == option.value ? .bold : .regular)
                                            .foregroundColor(frameInterval == option.value ? .white : .white.opacity(0.6))
                                            .padding(.vertical, DSSpacing.xxs)
                                            .padding(.horizontal, DSSpacing.sm)
                                            .background(
                                                RoundedRectangle(cornerRadius: DSCornerRadius.small)
                                                    .fill(frameInterval == option.value
                                                          ? Color.dsPrimary
                                                          : Color.clear)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(DSSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DSCornerRadius.small)
                                .fill(Color.white.opacity(0.06))
                        )

                        Button(action: { viewModel.processVideo(inputURL: selectedURL!, frameInterval: frameInterval) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("开始分析")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, DSSpacing.xl)
                            .padding(.vertical, DSSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                                    .fill(Color.dsPrimary)
                            )
                        }
                    }

                case .processing:
                    VStack(spacing: 12) {
                        ProgressView(value: viewModel.progress)
                            .tint(Color.dsPrimary)
                        Text("处理中 \(Int(viewModel.progress * 100))%")
                            .dsTextStyle(.caption1)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(DSSpacing.md)

                case .done(let outputURL):
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                        Text("处理完成")
                            .dsTextStyle(.body)
                            .foregroundColor(.white)

                        HStack(spacing: 16) {
                            Button(action: { showPlayer = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.rectangle")
                                    Text("播放")
                                }
                                .dsTextStyle(.caption1)
                                .foregroundColor(.white)
                                .padding(.horizontal, DSSpacing.md)
                                .padding(.vertical, DSSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: DSCornerRadius.small)
                                        .fill(Color.dsPrimary)
                                )
                            }

                            Button(action: { viewModel.saveToLibrary(url: outputURL) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("保存")
                                }
                                .dsTextStyle(.caption1)
                                .foregroundColor(.white)
                                .padding(.horizontal, DSSpacing.md)
                                .padding(.vertical, DSSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: DSCornerRadius.small)
                                        .fill(Color.dsSecondary)
                                )
                            }
                        }

                        Button(action: {
                            showPlayer = true
                        }) {
                            Text("")
                        }
                        .fullScreenCover(isPresented: $showPlayer) {
                            NavigationStack {
                                VideoPlayer(player: AVPlayer(url: outputURL))
                                    .ignoresSafeArea()
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("关闭") { showPlayer = false }
                                                .foregroundColor(.white)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(DSSpacing.md)

                case .error(let msg):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)
                        Text(msg)
                            .dsTextStyle(.caption1)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(DSSpacing.md)
                }
            }
            .padding(DSSpacing.lg)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .navigationTitle("视频分析")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPicker) {
            VideoPickerView { url in
                selectedURL = url
                loadVideoInfo(url: url)
                viewModel.reset()
            }
        }
    }

    private func loadVideoInfo(url: URL) {
        let asset = AVAsset(url: url)
        Task {
            let duration = try? await asset.load(.duration)
            if let dur = duration {
                let secs = Int(CMTimeGetSeconds(dur))
                videoDuration = "\(secs / 60):\(String(format: "%02d", secs % 60))"
            }
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                videoResolution = size.map { "\(Int($0.width))×\(Int($0.height))" }
            }
        }
    }
}
