import AVFoundation
import CoreMedia
import CoreImage

// MARK: - Video Recorder with skeleton overlay compositing

@available(iOS 17.0, *)
final class PoseVideoRecorder: @unchecked Sendable {

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var pixelBufferPool: CVPixelBufferPool?
    private var frameIndex: Int64 = 0
    private var dimensions: (width: Int, height: Int)?

    private let ciContext = CIContext()

    var isRecording: Bool { writer?.status == .writing }

    func start(outputURL: URL, width: Int, height: Int) throws {
        stop()
        dimensions = (width, height)

        writer = try AVAssetWriter(url: outputURL, fileType: .mov)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input?.expectsMediaDataInRealTime = true

        let sourceAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input!,
            sourcePixelBufferAttributes: sourceAttrs
        )

        // Pixel buffer pool for composited BGRA frames
        let poolAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        CVPixelBufferPoolCreate(nil, nil, poolAttrs as CFDictionary, &pixelBufferPool)

        guard let writer, let input, writer.canAdd(input) else {
            throw NSError(domain: "PoseVideoRecorder", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "AVAssetWriter setup failed"])
        }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        frameIndex = 0
    }

    func appendFrame(
        pixelBuffer: CVPixelBuffer,
        joints: BodyJoints,
        isFrontCamera: Bool
    ) {
        guard writer?.status == .writing,
              let adaptor,
              let input,
              input.isReadyForMoreMediaData,
              let dims = dimensions,
              let pool = pixelBufferPool else { return }

        // Get BGRA buffer from pool
        var outBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outBuffer) == kCVReturnSuccess,
              let composited = outBuffer else { return }

        // Convert camera YUV → CGImage via Core Image
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        CVPixelBufferLockBaseAddress(composited, [])
        defer { CVPixelBufferUnlockBaseAddress(composited, []) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(composited),
            width: dims.width,
            height: dims.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(composited),
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }

        let imageSize = CGSize(width: dims.width, height: dims.height)
        let imageRect = CGRect(origin: .zero, size: imageSize)

        // Draw camera image: CGImage bottom-left → bitmap top-left (flip Y)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(dims.height))
        ctx.scaleBy(x: 1, y: -1)

        if isFrontCamera {
            // Mirror image horizontally for front camera
            ctx.translateBy(x: CGFloat(dims.width), y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }

        ctx.draw(cgImage, in: imageRect)
        ctx.restoreGState()

        // Draw skeleton overlay (context is top-left origin)
        Skeleton3DRenderer.renderOntoContext(
            ctx,
            joints: joints,
            imageSize: imageSize,
            isFrontCamera: isFrontCamera
        )

        let time = CMTime(value: frameIndex, timescale: 30)
        adaptor.append(composited, withPresentationTime: time)
        frameIndex += 1
    }

    func stop() -> URL? {
        let url = writer?.outputURL
        input?.markAsFinished()
        writer?.finishWriting {}
        writer = nil
        input = nil
        adaptor = nil
        pixelBufferPool = nil
        dimensions = nil
        frameIndex = 0
        return url
    }
}
