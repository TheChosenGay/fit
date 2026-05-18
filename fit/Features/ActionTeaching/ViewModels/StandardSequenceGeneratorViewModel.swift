import SwiftUI
import SwiftData
import PhotosUI
import CoreMedia
import Combine
import UniformTypeIdentifiers
import ImageIO

private struct VideoFileTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let dest = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

@available(iOS 17.0, *)
@MainActor
final class StandardSequenceGeneratorViewModel: ObservableObject {

    enum GenerationState {
        case idle
        case processing(progress: Float)
        case completed(StandardActionSequence)
        case failed(String)
    }

    @Published var state: GenerationState = .idle
    @Published var exerciseId: String = ""
    @Published var exerciseName: String = ""
    @Published var selectedVideoItem: PhotosPickerItem?

    private let actionService: StandardActionService
    private var modelContext: ModelContext?

    init(actionService: StandardActionService = LocalStandardActionService()) {
        self.actionService = actionService
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func generateFromVideo(url: URL) async {
        guard !exerciseId.isEmpty else {
            state = .failed("请输入动作 ID")
            return
        }

        state = .processing(progress: 0)

        do {
            let sequence = try await extractSequence(from: url)
            try saveSequence(sequence)
            state = .completed(sequence)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func generateFromPickerItem() async {
        guard let item = selectedVideoItem else { return }

        do {
            guard let video = try await item.loadTransferable(type: VideoFileTransferable.self) else {
                state = .failed("无法加载视频")
                return
            }
            await generateFromVideo(url: video.url)
            try? FileManager.default.removeItem(at: video.url)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Extraction Pipeline

    private func extractSequence(from videoURL: URL) async throws -> StandardActionSequence {
        let asset = AVURLAsset(url: videoURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw GenerationError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let durationMs = Int(CMTimeGetSeconds(duration) * 1000)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let fps = Int(nominalFrameRate)
        let targetFps = 10
        let frameSkip = max(1, fps / targetFps)
        let totalFrames = max(1, Int(Float(durationMs) / 1000.0 * Float(fps)))
        let transform = try await videoTrack.load(.preferredTransform)
        let videoOrientation = Self.orientationFromTransform(transform)

        let frames: [SequenceFrame] = try await Task.detached(priority: .userInitiated) {
            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
            trackOutput.alwaysCopiesSampleData = false
            reader.add(trackOutput)
            reader.startReading()

            let detector = RTMPoseDetector.detector
            var result: [SequenceFrame] = []
            var frameIndex = 0

            while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                defer { frameIndex += 1 }
                if frameIndex % frameSkip != 0 { continue }

                let timeMs = Int(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000)

                let joints: [String: JointPosition3D]? = autoreleasepool {
                    guard let bodyJoints = detector.detectBodyPoseSync(from: sampleBuffer, orientation: videoOrientation) else { return nil }

                    var mapped: [String: JointPosition3D] = [:]
                    for j in bodyJoints {
                        let name = WholeBodyJointMap.legacyMapping.first(where: { $0.value == j.joint })?.key ?? j.joint
                        mapped[name] = JointPosition3D(
                            x: Float(j.location2D.x),
                            y: Float(j.location2D.y),
                            z: 0
                        )
                    }
                    return mapped
                }

                if let joints = joints {
                    result.append(SequenceFrame(timeMs: timeMs, joints: joints))
                }

                if frameIndex % (frameSkip * 5) == 0 {
                    let progress = min(Float(frameIndex) / Float(totalFrames), 0.99)
                    Task { @MainActor in
                        self.state = .processing(progress: progress)
                    }
                }
            }

            return result
        }.value

        guard !frames.isEmpty else { throw GenerationError.noFramesDetected }

        let metadata = SequenceMetadata(
            exerciseName: exerciseName.isEmpty ? exerciseId : exerciseName,
            exerciseId: exerciseId,
            author: "user",
            createdAt: Date(),
            description: "用户生成的标准动作序列",
            difficulty: "intermediate",
            durationMs: durationMs,
            sourceVideoHash: nil,
            tags: []
        )

        let config = SequenceConfig(
            fps: min(fps, 30),
            jointSet: "coco_wholebody_133",
            coordinateSpace: "normalized_2d",
            rootJoint: "left_hip",
            isLoopable: true,
            phaseMarkers: [],
            criticalJoints: [],
            toleranceProfile: ToleranceProfile(global: 0.15, jointOverrides: nil)
        )

        return StandardActionSequence(
            id: "\(exerciseId)_standard_v1",
            version: 1,
            metadata: metadata,
            config: config,
            frames: frames
        )
    }

    private func saveSequence(_ sequence: StandardActionSequence) throws {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("StandardSequences")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileName = "\(sequence.id).json"
        let fileURL = dir.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(sequence)
        try data.write(to: fileURL)

        // 写入 SwiftData catalog
        guard let context = modelContext else { return }
        let catalog = StandardSequenceCatalog(
            sequenceId: sequence.id,
            exerciseId: sequence.metadata.exerciseId,
            exerciseName: sequence.metadata.exerciseName,
            version: sequence.version,
            difficulty: sequence.metadata.difficulty,
            localFilePath: "StandardSequences/\(fileName)",
            isBuiltIn: false,
            fileSize: data.count
        )
        context.insert(catalog)
        try context.save()
    }

    enum GenerationError: LocalizedError {
        case noVideoTrack
        case noFramesDetected

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: return "视频中没有找到视频轨道"
            case .noFramesDetected: return "未检测到任何姿态帧"
            }
        }
    }

    private static func orientationFromTransform(_ transform: CGAffineTransform) -> CGImagePropertyOrientation {
        let angle = atan2(transform.b, transform.a)
        switch Int(round(angle * 180 / .pi)) {
        case 0: return .up
        case 90: return .right
        case -90, 270: return .left
        case 180, -180: return .down
        default: return .up
        }
    }
}
