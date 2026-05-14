import UIKit
import Vision
import CoreImage

enum EdgeDetector {
    /// 人像分割 → Canny 边缘检测 → 骨骼叠加 合成图（用于多模态 AI 分析）
    /// 背景替换为黑色，仅保留人物白色边缘 + 绿色骨骼标注
    static func composite(image: UIImage, points: [PosePoint] = [], maxEdge: CGFloat = 512) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let scale = maxEdge / max(CGFloat(cgImage.width), CGFloat(cgImage.height))
        let targetW = Int(CGFloat(cgImage.width) * scale)
        let targetH = Int(CGFloat(cgImage.height) * scale)
        guard targetW > 0, targetH > 0 else { return nil }

        let renderSize = CGSize(width: targetW, height: targetH)
        let mask = personMask(cgImage: cgImage)?.flippedVertically()

        // 步骤1：人像分割 → 黑色背景 + 人物
        // 步骤2：对分割结果做 Canny 边缘检测
        let baseImage: UIImage
        if let mask, let personCG = renderPerson(cgImage: cgImage, mask: mask, size: renderSize) {
            baseImage = cannyEdgeDetect(personCG) ?? UIImage(cgImage: personCG)
        } else if let canny = cannyEdgeDetect(cgImage) {
            baseImage = canny
        } else {
            baseImage = UIImage(cgImage: cgImage)
        }

        guard !points.isEmpty else { return baseImage }

        // 步骤3：叠加绿色骨骼
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { ctx in
            baseImage.draw(in: CGRect(origin: .zero, size: renderSize))
            drawSkeleton(points: points, renderSize: renderSize)
        }
    }

    // MARK: - Person segmentation

    private static func personMask(cgImage: CGImage) -> CGImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
            guard let maskPixelBuffer = request.results?.first?.pixelBuffer else { return nil }
            return pixelBufferToCGImage(maskPixelBuffer)
        } catch {
            print("[EdgeDetector] 人像分割失败: \(error)")
            return nil
        }
    }

    private static func pixelBufferToCGImage(_ pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    // MARK: - Person render (black bg + masked person)

    private static func renderPerson(cgImage: CGImage, mask: CGImage, size: CGSize) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let scaledMask = mask.scaledToFit(size)
            let rect = scaledMask.map {
                CGRect(x: (size.width - CGFloat($0.width)) / 2,
                       y: (size.height - CGFloat($0.height)) / 2,
                       width: CGFloat($0.width), height: CGFloat($0.height))
            } ?? CGRect(origin: .zero, size: size)

            ctx.cgContext.saveGState()
            ctx.cgContext.clip(to: rect, mask: mask)
            UIImage(cgImage: cgImage).draw(in: rect)
            ctx.cgContext.restoreGState()
        }
        return uiImage.cgImage
    }

    // MARK: - Canny edge detection

    private static func cannyEdgeDetect(_ cgImage: CGImage) -> UIImage? {
        let ciImage = CIImage(cgImage: cgImage)
        let canny = ciImage
            .applyingFilter("CICannyEdgeDetector")
            .applyingFilter("CIColorInvert")
     
        let context = CIContext()
        guard let outputCG = context.createCGImage(canny, from: canny.extent) else { return nil }
        return UIImage(cgImage: outputCG)
    }

    // MARK: - Skeleton overlay

    private static func drawSkeleton(points: [PosePoint], renderSize: CGSize) {
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })
        let connections: [(String, String)] = [
            // Body (15)
            ("left_ear_joint", "neck_1_joint"), ("right_ear_joint", "neck_1_joint"),
            ("neck_1_joint", "left_shoulder_1_joint"), ("left_shoulder_1_joint", "left_forearm_joint"), ("left_forearm_joint", "left_hand_joint"),
            ("neck_1_joint", "right_shoulder_1_joint"), ("right_shoulder_1_joint", "right_forearm_joint"), ("right_forearm_joint", "right_hand_joint"),
            ("neck_1_joint", "root"),
            ("root", "left_upLeg_joint"), ("left_upLeg_joint", "left_leg_joint"), ("left_leg_joint", "left_foot_joint"),
            ("root", "right_upLeg_joint"), ("right_upLeg_joint", "right_leg_joint"), ("right_leg_joint", "right_foot_joint"),
            ("left_shoulder_1_joint", "right_shoulder_1_joint"),
            ("left_upLeg_joint", "right_upLeg_joint"),
            // Feet (6)
            ("left_foot_joint", "left_big_toe"), ("left_foot_joint", "left_small_toe"), ("left_foot_joint", "left_heel"),
            ("right_foot_joint", "right_big_toe"), ("right_foot_joint", "right_small_toe"), ("right_foot_joint", "right_heel"),
            // Left hand (20)
            ("left_hand_joint", "left_thumb_1"), ("left_thumb_1", "left_thumb_2"), ("left_thumb_2", "left_thumb_3"), ("left_thumb_3", "left_thumb_4"),
            ("left_hand_joint", "left_index_1"), ("left_index_1", "left_index_2"), ("left_index_2", "left_index_3"), ("left_index_3", "left_index_4"),
            ("left_hand_joint", "left_middle_1"), ("left_middle_1", "left_middle_2"), ("left_middle_2", "left_middle_3"), ("left_middle_3", "left_middle_4"),
            ("left_hand_joint", "left_ring_1"), ("left_ring_1", "left_ring_2"), ("left_ring_2", "left_ring_3"), ("left_ring_3", "left_ring_4"),
            ("left_hand_joint", "left_pinky_1"), ("left_pinky_1", "left_pinky_2"), ("left_pinky_2", "left_pinky_3"), ("left_pinky_3", "left_pinky_4"),
            // Right hand (20)
            ("right_hand_joint", "right_thumb_1"), ("right_thumb_1", "right_thumb_2"), ("right_thumb_2", "right_thumb_3"), ("right_thumb_3", "right_thumb_4"),
            ("right_hand_joint", "right_index_1"), ("right_index_1", "right_index_2"), ("right_index_2", "right_index_3"), ("right_index_3", "right_index_4"),
            ("right_hand_joint", "right_middle_1"), ("right_middle_1", "right_middle_2"), ("right_middle_2", "right_middle_3"), ("right_middle_3", "right_middle_4"),
            ("right_hand_joint", "right_ring_1"), ("right_ring_1", "right_ring_2"), ("right_ring_2", "right_ring_3"), ("right_ring_3", "right_ring_4"),
            ("right_hand_joint", "right_pinky_1"), ("right_pinky_1", "right_pinky_2"), ("right_pinky_2", "right_pinky_3"), ("right_pinky_3", "right_pinky_4"),
        ]

        func denorm(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * renderSize.width, y: (1.0 - p.y) * renderSize.height)
        }

        let linePath = UIBezierPath()
        linePath.lineWidth = max(renderSize.width, renderSize.height) * 0.004
        for (j1, j2) in connections {
            guard let p1 = dict[j1], let p2 = dict[j2],
                  p1.confidence > 0.3, p2.confidence > 0.3 else { continue }
            linePath.move(to: denorm(p1.location))
            linePath.addLine(to: denorm(p2.location))
        }
        UIColor.green.withAlphaComponent(0.8).setStroke()
        linePath.stroke()

        for (_, p) in dict where p.confidence > 0.3 {
            let center = denorm(p.location)
            let radius = max(renderSize.width, renderSize.height) * 0.012
            let color: UIColor = p.confidence > 0.6
                ? UIColor.green.withAlphaComponent(0.95)
                : UIColor.yellow.withAlphaComponent(0.75)
            let circle = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            color.setFill()
            circle.fill()
        }
    }
}

// MARK: - CGImage helpers

private extension CGImage {
    func scaledToFit(_ target: CGSize) -> CGImage? {
        let scale = min(target.width / CGFloat(width), target.height / CGFloat(height))
        let w = Int(CGFloat(width) * scale)
        let h = Int(CGFloat(height) * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                   bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(self, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    /// Vision 输出的 mask 原点在左下，CGContext clip mask 期望原点在左上，故需垂直翻转
    func flippedVertically() -> CGImage? {
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
