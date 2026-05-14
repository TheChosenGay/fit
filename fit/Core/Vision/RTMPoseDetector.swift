import CoreML
import Vision
import CoreMedia
import CoreImage
import UIKit

@available(iOS 17.0, *)
final class RTMPoseDetector {

    nonisolated static let detector = RTMPoseDetector()

    private let modelInputWidth = 192
    private let modelInputHeight = 256
    private let confidenceThreshold: Float = 0.3

    // SimCC doubles the resolution
    private let simccScaleX: Float = 2.0
    private let simccScaleY: Float = 2.0

    private lazy var poseModel: MLModel? = {
        guard let url = Bundle.main.url(forResource: "RTMPoseWholeBody", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "RTMPoseWholeBody", withExtension: "mlpackage") else {
            print("[RTMPoseDetector] Model file not found in bundle")
            return nil
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return try? MLModel(contentsOf: url, configuration: config)
    }()

    private let personDetectRequest = VNDetectHumanRectanglesRequest()
    private let ciContext = CIContext()

    private init() {}

    // MARK: - Decode SimCC output

    private func toFloatArray(_ mlArray: MLMultiArray) -> [Float] {
        let count = mlArray.count
        var result = [Float](repeating: 0, count: count)
        if mlArray.dataType == .float16 {
            let src = mlArray.dataPointer.assumingMemoryBound(to: Float16.self)
            for i in 0..<count { result[i] = Float(src[i]) }
        } else {
            let src = mlArray.dataPointer.assumingMemoryBound(to: Float.self)
            for i in 0..<count { result[i] = src[i] }
        }
        return result
    }

    private func decodeSimCC(
        simccX: MLMultiArray,
        simccY: MLMultiArray,
        personBBox: CGRect,
        fullWidth: CGFloat,
        fullHeight: CGFloat
    ) -> BodyJoints {
        let numKeypoints = simccX.shape[1].intValue
        let simccW = simccX.shape[2].intValue
        let simccH = simccY.shape[2].intValue

        let xData = toFloatArray(simccX)
        let yData = toFloatArray(simccY)

        var joints = BodyJoints()

        for k in 0..<numKeypoints {
            let xOffset = k * simccW
            var bestXIdx = 0
            var bestXVal = xData[xOffset]
            for i in 1..<simccW {
                let v = xData[xOffset + i]
                if v > bestXVal { bestXVal = v; bestXIdx = i }
            }

            let yOffset = k * simccH
            var bestYIdx = 0
            var bestYVal = yData[yOffset]
            for i in 1..<simccH {
                let v = yData[yOffset + i]
                if v > bestYVal { bestYVal = v; bestYIdx = i }
            }

            let conf = (bestXVal + bestYVal) / 2.0
            guard conf > confidenceThreshold else { continue }

            let xInCrop = Float(bestXIdx) / simccScaleX
            let yInCrop = Float(bestYIdx) / simccScaleY

            let xNormCrop = xInCrop / Float(modelInputWidth)
            let yNormCrop = yInCrop / Float(modelInputHeight)

            let xFull = Float(personBBox.origin.x) + xNormCrop * Float(personBBox.width)
            let yFull = Float(personBBox.origin.y) + (1 - yNormCrop) * Float(personBBox.height)

            let name = WholeBodyJointMap.canonicalName(for: k)
            joints.append(BodyJoint(
                joint: name,
                location2D: CGPoint(x: CGFloat(xFull), y: CGFloat(yFull)),
                position3D: nil,
                confidence: conf
            ))
        }

        return joints
    }

    // MARK: - Person Detection

    private func detectPersonBBox(handler: VNImageRequestHandler) -> CGRect? {
        try? handler.perform([personDetectRequest])
        return personDetectRequest.results?
            .sorted { $0.confidence > $1.confidence }
            .first?
            .boundingBox
    }

    // MARK: - Crop + Resize pixel buffer

    private func cropAndResize(
        pixelBuffer: CVPixelBuffer,
        bbox: CGRect
    ) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let w = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let h = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        // Vision bbox is bottom-left origin normalized → pixel rect (top-left origin for CI)
        let cropRect = CGRect(
            x: bbox.origin.x * w,
            y: bbox.origin.y * h,
            width: bbox.width * w,
            height: bbox.height * h
        )

        let cropped = ciImage.cropped(to: cropRect)

        let scaleX = CGFloat(modelInputWidth) / cropRect.width
        let scaleY = CGFloat(modelInputHeight) / cropRect.height
        let scaled = cropped
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var outputBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            modelInputWidth, modelInputHeight,
            kCVPixelFormatType_32BGRA, nil,
            &outputBuffer
        )
        guard let output = outputBuffer else { return nil }

        ciContext.render(scaled, to: output)
        return output
    }

    // MARK: - CoreML Inference

    private func predict(pixelBuffer: CVPixelBuffer) -> (simccX: MLMultiArray, simccY: MLMultiArray)? {
        guard let model = poseModel else { return nil }

        guard let inputFeature = try? MLDictionaryFeatureProvider(
            dictionary: ["input": MLFeatureValue(pixelBuffer: pixelBuffer)]
        ) else { return nil }

        guard let output = try? model.prediction(from: inputFeature) else { return nil }

        guard let simccX = output.featureValue(for: "simcc_x")?.multiArrayValue,
              let simccY = output.featureValue(for: "simcc_y")?.multiArrayValue else { return nil }

        return (simccX, simccY)
    }
}

// MARK: - BodyPoseDetectService (real-time CMSampleBuffer)

@available(iOS 17.0, *)
extension RTMPoseDetector: BodyPoseDetectService {

    func detectBodyPose(from sampleBuffer: CMSampleBuffer) async throws -> BodyJoints? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        guard let bbox = detectPersonBBox(handler: handler) else { return nil }
        guard let croppedBuffer = cropAndResize(pixelBuffer: pixelBuffer, bbox: bbox) else { return nil }
        guard let (simccX, simccY) = predict(pixelBuffer: croppedBuffer) else { return nil }

        let fullW = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let fullH = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        let allJoints = decodeSimCC(
            simccX: simccX, simccY: simccY,
            personBBox: bbox, fullWidth: fullW, fullHeight: fullH
        )

        let legacyJoints = WholeBodyJointMap.filterToLegacyBody(allJoints)
        return legacyJoints.isEmpty ? nil : legacyJoints
    }
}

// MARK: - PoseDetectService (static UIImage)

@available(iOS 17.0, *)
extension RTMPoseDetector: PoseDetectService {

    func detectPose(from image: UIImage) async throws -> PosePoints? {
        guard let cgImage = image.cgImage else { return nil }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard let bbox = detectPersonBBox(handler: handler) else { return nil }

        // Create CVPixelBuffer from CGImage
        let ciImage = CIImage(cgImage: cgImage)
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        var srcBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, cgImage.width, cgImage.height,
                            kCVPixelFormatType_32BGRA, nil, &srcBuffer)
        guard let src = srcBuffer else { return nil }
        ciContext.render(ciImage, to: src)

        guard let croppedBuffer = cropAndResize(pixelBuffer: src, bbox: bbox) else { return nil }
        guard let (simccX, simccY) = predict(pixelBuffer: croppedBuffer) else { return nil }

        let allJoints = decodeSimCC(
            simccX: simccX, simccY: simccY,
            personBBox: bbox, fullWidth: w, fullHeight: h
        )

        let legacyPoints = WholeBodyJointMap.filterToLegacyPosePoints(allJoints)
        return legacyPoints.isEmpty ? nil : legacyPoints
    }
}
