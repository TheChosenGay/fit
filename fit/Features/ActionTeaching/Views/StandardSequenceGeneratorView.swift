import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

@available(iOS 17.0, *)
struct StandardSequenceGeneratorView: View {

    @StateObject private var viewModel = StandardSequenceGeneratorViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showVideoPicker = false

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            inputSection
            actionSection
            statusSection
            Spacer()
        }
        .padding()
        .navigationTitle("生成标准动作")
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("导入标准视频")
                .font(.title2.bold())
            Text("选择一段标准动作视频，系统将自动检测姿态并生成标准动作序列")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            TextField("动作 ID（如 squat）", text: $viewModel.exerciseId)
                .textFieldStyle(.roundedBorder)
            TextField("动作名称（如 深蹲）", text: $viewModel.exerciseName)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var actionSection: some View {
        PhotosPicker(
            selection: $viewModel.selectedVideoItem,
            matching: .videos
        ) {
            Label("选择视频", systemImage: "video.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .onChange(of: viewModel.selectedVideoItem) { _ in
            Task {
                await viewModel.generateFromPickerItem()
            }
        }
    }

    private var statusSection: some View {
        Group {
            switch viewModel.state {
            case .idle:
                EmptyView()
            case .processing(let progress):
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .tint(.blue)
                    Text("正在分析视频... \(Int(progress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            case .completed(let sequence):
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("生成完成")
                        .font(.headline)
                    Text("\(sequence.frames.count) 帧 · \(sequence.metadata.durationMs / 1000)秒")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("已保存至 Documents/StandardSequences/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .failed(let message):
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
        }
    }
}
