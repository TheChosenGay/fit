import Foundation
import CoreVideo
import Vision
import ARKit

// MARK: - Per-instance result

struct FoodInstance {
    let id: Int
    let volumeML: Float
    /// Normalized centroid (0–1), for spatial matching with AI food items
    let centroidX: Float
    let centroidY: Float
}

// MARK: - Food volume estimator (LiDAR + Vision foreground instance mask)

@available(iOS 17.0, *)
final class FoodVolumeEstimator {

    /// Whether the device has LiDAR and supports scene reconstruction.
    static var hasLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    /// Estimate per-instance food volumes from an ARFrame.
    /// Returns instances sorted top-to-bottom (ascending centroidY).
    static func estimateVolumes(from frame: ARFrame) async -> [FoodInstance]? {
        guard hasLiDAR,
              let depthMap = frame.sceneDepth?.depthMap else { return nil }

        let capturedImage = frame.capturedImage
        guard let maskBuffer = await generateForegroundMask(from: capturedImage) else { return nil }

        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]

        return computePerInstanceVolumes(depthMap: depthMap, mask: maskBuffer, fx: fx, fy: fy)
    }

    // MARK: - Volume computation (per-instance, single pass)

    private static func computePerInstanceVolumes(
        depthMap: CVPixelBuffer,
        mask: CVPixelBuffer,
        fx: Float,
        fy: Float
    ) -> [FoodInstance] {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(mask, .readOnly)
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        }

        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        let maskWidth = CVPixelBufferGetWidth(mask)
        let maskHeight = CVPixelBufferGetHeight(mask)

        guard let depthPtr = CVPixelBufferGetBaseAddress(depthMap)?
            .assumingMemoryBound(to: Float32.self),
              let maskPtr = CVPixelBufferGetBaseAddress(mask)?
            .assumingMemoryBound(to: UInt8.self)
        else { return [] }

        let scaleX = Float(maskWidth) / Float(depthWidth)
        let scaleY = Float(maskHeight) / Float(depthHeight)
        let fxInv: Float = 1.0 / fx
        let fyInv: Float = 1.0 / fy

        // Per-instance accumulators
        var volumesM3: [Int: Float] = [:]
        var sumX: [Int: Float] = [:]
        var sumY: [Int: Float] = [:]
        var counts: [Int: Int] = [:]

        for dy in 0..<depthHeight {
            for dx in 0..<depthWidth {
                let depth = depthPtr[dy * depthWidth + dx]
                guard depth > 0.1, depth < 3.0 else { continue } // valid: 10cm–3m

                let mx = Int(Float(dx) * scaleX)
                let my = Int(Float(dy) * scaleY)
                guard mx >= 0, mx < maskWidth, my >= 0, my < maskHeight else { continue }

                let instanceID = Int(maskPtr[my * maskWidth + mx])
                guard instanceID > 0 else { continue } // skip background

                let pixelWidth = depth * fxInv
                let pixelHeight = depth * fyInv
                let pixelArea = pixelWidth * pixelHeight
                let pixelVolume = pixelArea * depth

                volumesM3[instanceID, default: 0] += pixelVolume
                sumX[instanceID, default: 0] += Float(dx)
                sumY[instanceID, default: 0] += Float(dy)
                counts[instanceID, default: 0] += 1
            }
        }

        let instances: [FoodInstance] = volumesM3.compactMap { (id, volM3) in
            guard let count = counts[id], count > 0 else { return nil }
            return FoodInstance(
                id: id,
                volumeML: volM3 * 1_000_000, // m³ → ml
                centroidX: (sumX[id] ?? 0) / Float(count) / Float(depthWidth),
                centroidY: (sumY[id] ?? 0) / Float(count) / Float(depthHeight)
            )
        }

        // Sort top-to-bottom for matching with AI food items (also listed top-to-bottom)
        return instances.sorted { $0.centroidY < $1.centroidY }
    }

    // MARK: - Foreground mask generation

    private static func generateForegroundMask(from pixelBuffer: CVPixelBuffer) async -> CVPixelBuffer? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let result = request.results?.first else { return nil }
        // Combined mask with per-pixel instance IDs (0 = background, 1+ = instance index)
        return try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
    }
}

// MARK: - Spatial matching helper
@available(iOS 17.0, *)
extension FoodVolumeEstimator {

    /// Match LiDAR instances to AI food items by spatial position.
    ///
    /// Both `instances` and `aiItems` are assumed to be sorted top-to-bottom.
    /// If counts don't match, the extra instances/items are merged or dropped
    /// proportionally.
    ///
    /// - Returns: Dictionary `foodItemName → volumeML`.
    static func matchVolumes(
        instances: [FoodInstance],
        to foodItems: [ItemNutrition]
    ) -> [String: Float] {
        guard !instances.isEmpty, !foodItems.isEmpty else { return [:] }

        if instances.count == foodItems.count {
            // Direct 1:1 match by position (both sorted top-to-bottom)
            return Dictionary(uniqueKeysWithValues: zip(foodItems, instances).map { item, inst in
                (item.name, inst.volumeML)
            })
        }

        // Mismatched counts — distribute total volume proportionally by AI gram estimates
        let totalVolume = instances.reduce(0.0) { $0 + $1.volumeML }
        let totalGrams = foodItems.reduce(0.0) { $0 + Double($1.estimatedGrams) }
        guard totalGrams > 0 else { return [:] }
        return Dictionary(uniqueKeysWithValues: foodItems.map { item in
            let proportion = Float(Double(item.estimatedGrams) / totalGrams)
            return (item.name, totalVolume * proportion)
        })
    }
}
