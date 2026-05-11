import UIKit
import Vision
import CoreImage

enum EdgeDetector {
    /// 人像分割 + 骨骼叠加 合成图（用于多模态 AI 分析）
    /// 背景替换为黑色，仅保留人物 + 绿色骨骼标注
    static func composite(image: UIImage, points: [PosePoint] = [], maxEdge: CGFloat = 512) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let scale = maxEdge / max(CGFloat(cgImage.width), CGFloat(cgImage.height))
        let targetW = Int(CGFloat(cgImage.width) * scale)
        let targetH = Int(CGFloat(cgImage.height) * scale)
        guard targetW > 0, targetH > 0 else { return nil }

        // 人像分割
        let mask = personMask(cgImage: cgImage)

        // 缩放到目标尺寸
        let renderSize = CGSize(width: targetW, height: targetH)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { ctx in
            // 黑色背景
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderSize))

            // 用蒙版绘制人物（仅保留人像，背景为黑）
            if let mask {
                let maskScaled = mask.scaledToFit(CGSize(width: targetW, height: targetH))
                let personRect = maskScaled.map {
                    CGRect(x: (renderSize.width - CGFloat($0.width)) / 2,
                           y: (renderSize.height - CGFloat($0.height)) / 2,
                           width: CGFloat($0.width), height: CGFloat($0.height))
                } ?? CGRect(origin: .zero, size: renderSize)

                // 绘制原图，用蒙版裁切
                let cgCtx = ctx.cgContext
                cgCtx.saveGState()
                cgCtx.clip(to: personRect, mask: mask)
                UIImage(cgImage: cgImage).draw(in: personRect)
                cgCtx.restoreGState()
            } else {
                // 无蒙版时降级：直接绘制原图
                UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: renderSize))
            }

            guard !points.isEmpty else { return }

            let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })
            let connections: [(String, String)] = [
                ("left_ear_joint", "neck_1_joint"), ("right_ear_joint", "neck_1_joint"),
                ("neck_1_joint", "left_shoulder_1_joint"), ("left_shoulder_1_joint", "left_forearm_joint"), ("left_forearm_joint", "left_hand_joint"),
                ("neck_1_joint", "right_shoulder_1_joint"), ("right_shoulder_1_joint", "right_forearm_joint"), ("right_forearm_joint", "right_hand_joint"),
                ("neck_1_joint", "root"),
                ("root", "left_upLeg_joint"), ("left_upLeg_joint", "left_leg_joint"), ("left_leg_joint", "left_foot_joint"),
                ("root", "right_upLeg_joint"), ("right_upLeg_joint", "right_leg_joint"), ("right_leg_joint", "right_foot_joint"),
                ("left_shoulder_1_joint", "right_shoulder_1_joint"),
                ("left_upLeg_joint", "right_upLeg_joint"),
            ]

            func denorm(_ p: CGPoint) -> CGPoint {
                CGPoint(x: p.x * renderSize.width, y: (1.0 - p.y) * renderSize.height)
            }

            let path = UIBezierPath()
            path.lineWidth = max(renderSize.width, renderSize.height) * 0.004
            for (j1, j2) in connections {
                guard let p1 = dict[j1], let p2 = dict[j2],
                      p1.confidence > 0.3, p2.confidence > 0.3 else { continue }
                path.move(to: denorm(p1.location))
                path.addLine(to: denorm(p2.location))
            }
            UIColor.green.withAlphaComponent(0.8).setStroke()
            path.stroke()

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
}

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
}
