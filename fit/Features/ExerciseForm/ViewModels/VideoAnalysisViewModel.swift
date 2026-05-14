import SwiftUI
import AVFoundation
import Photos
import Combine

@available(iOS 17.0, *)
@MainActor
final class VideoAnalysisViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case processing
        case done(outputURL: URL)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var progress: Double = 0

    private var processingTask: Task<Void, Never>?

    // MARK: - Process video

    func processVideo(inputURL: URL, frameInterval: Int = 4) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("analyzed_\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: outputURL)

        state = .processing
        progress = 0

        processingTask = Task.detached { [weak self, frameInterval] in
            guard let self else { return }

            do {
                let asset = AVAsset(url: inputURL)
                let duration = try await asset.load(.duration)
                let totalSeconds = CMTimeGetSeconds(duration)
                let estimatedFrames = Int(totalSeconds * 30)

                // Reader
                let reader = try AVAssetReader(asset: asset)
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    throw ProcessingError.noVideoTrack
                }

                let naturalSize = try await videoTrack.load(.naturalSize)
                let outputSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))

                let readerOutputSettings: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                ]
                let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
                reader.add(readerOutput)
                guard reader.startReading() else { throw ProcessingError.cannotRead }

                // Writer
                let writer = try AVAssetWriter(url: outputURL, fileType: .mov)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: outputSize.width,
                    AVVideoHeightKey: outputSize.height,
                ]
                let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                writerInput.expectsMediaDataInRealTime = false

                let sourceAttrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(outputSize.width),
                    kCVPixelBufferHeightKey as String: Int(outputSize.height),
                ]
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: writerInput,
                    sourcePixelBufferAttributes: sourceAttrs
                )

                guard writer.canAdd(writerInput) else { throw ProcessingError.cannotWrite }
                writer.add(writerInput)
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)

                // Pixel buffer pool
                var pool: CVPixelBufferPool?
                let poolAttrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(outputSize.width),
                    kCVPixelBufferHeightKey as String: Int(outputSize.height),
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                ]
                CVPixelBufferPoolCreate(nil, nil, poolAttrs as CFDictionary, &pool)

                let ciContext = CIContext()
                let detector = RTMPoseDetector.detector
                var frameIndex = 0
                var outputFrameIndex: Int64 = 0

                while reader.status == .reading {
                    if Task.isCancelled { break }

                    guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else { break }
                    defer { frameIndex += 1 }

                    guard frameIndex % frameInterval == 0 else { continue }
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

                    // Convert to UIImage
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { continue }
                    let uiImage = UIImage(cgImage: cgImage)

                    // Pose detection
                    guard let points = try? await detector.detectPose(from: uiImage), !points.isEmpty else {
                        writeFrame(pixelBuffer: pixelBuffer, adaptor: adaptor, writerInput: writerInput,
                                   frameIndex: outputFrameIndex, pool: pool, outputSize: outputSize)
                        outputFrameIndex += 1
                        continue
                    }

                    // Render skeleton
                    let annotated = SkeletonRenderer.render(image: uiImage, points: points)
                    guard let annotatedCG = annotated.cgImage else { continue }

                    // Draw into output buffer
                    var outBuffer: CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool!, &outBuffer)
                    guard let renderedBuffer = outBuffer else { continue }

                    CVPixelBufferLockBaseAddress(renderedBuffer, [])
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
                        | CGImageAlphaInfo.premultipliedFirst.rawValue
                    if let ctx = CGContext(
                        data: CVPixelBufferGetBaseAddress(renderedBuffer),
                        width: Int(outputSize.width),
                        height: Int(outputSize.height),
                        bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(renderedBuffer),
                        space: colorSpace,
                        bitmapInfo: bitmapInfo
                    ) {
                        ctx.draw(annotatedCG, in: CGRect(origin: .zero, size: outputSize))
                    }
                    CVPixelBufferUnlockBaseAddress(renderedBuffer, [])

                    writeFrame(pixelBuffer: renderedBuffer, adaptor: adaptor, writerInput: writerInput,
                               frameIndex: outputFrameIndex, pool: pool, outputSize: outputSize)
                    outputFrameIndex += 1

                    // Progress
                    let p = min(1.0, Double(frameIndex) / Double(max(estimatedFrames, 1)))
                    await MainActor.run { [weak self] in
                        self?.progress = p
                    }
                }

                writerInput.markAsFinished()
                await writer.finishWriting()

                let finalURL = writer.status == .completed ? outputURL : inputURL
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if writer.status == .completed {
                        self.state = .done(outputURL: finalURL)
                    } else {
                        self.state = .error(writer.error?.localizedDescription ?? "写入失败")
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.state = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Helpers

    private nonisolated func writeFrame(
        pixelBuffer: CVPixelBuffer,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        writerInput: AVAssetWriterInput,
        frameIndex: Int64,
        pool: CVPixelBufferPool?,
        outputSize: CGSize
    ) {
        let time = CMTime(value: frameIndex, timescale: 30)
        while !writerInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }
        adaptor.append(pixelBuffer, withPresentationTime: time)
    }

    // MARK: - Save to photo library

    func saveToLibrary(url: URL) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { return }
            try? await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        }
    }

    func reset() {
        processingTask?.cancel()
        processingTask = nil
        state = .idle
        progress = 0
    }

    func cancel() {
        processingTask?.cancel()
        processingTask = nil
        state = .idle
        progress = 0
    }
}

enum ProcessingError: LocalizedError {
    case noVideoTrack
    case cannotRead
    case cannotWrite

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "视频中没有找到视频轨道"
        case .cannotRead: return "无法读取视频"
        case .cannotWrite: return "无法创建输出文件"
        }
    }
}
