import UIKit
import CoreImage

enum EdgeDetector {
    /// 边缘 + 骨骼 合成图（用于多模态 AI 分析）
    /// - Parameters:
    ///   - image: 原始照片
    ///   - points: 姿态关键点（可选）
    ///   - maxEdge: 边缘图最长边尺寸，默认 512px
    /// - Returns: 合成后的边缘图
    static func composite(image: UIImage, points: [PosePoint] = [], maxEdge: CGFloat = 512) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        // 缩放到 maxEdge
        let scale = maxEdge / max(ciImage.extent.width, ciImage.extent.height)
        let targetW = Int(ciImage.extent.width * scale)
        let targetH = Int(ciImage.extent.height * scale)
        guard targetW > 0, targetH > 0 else { return nil }

        guard let edge = CIFilter(name: "CICannyEdgeDetector", parameters: [
            kCIInputImageKey: ciImage,
            "inputGaussianSigma": 1.5,
            "inputPerceptual": true,
        ])?.outputImage else { return nil }

        // 缩放到目标尺寸
        let edgeScaled = edge.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let edgeCG = context.createCGImage(edgeScaled, from: CGRect(x: 0, y: 0, width: targetW, height: targetH)) else { return nil }

        let renderSize = CGSize(width: targetW, height: targetH)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { ctx in
            // 黑色背景
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderSize))

            // 边缘图（白色线条）
            UIImage(cgImage: edgeCG).draw(in: CGRect(origin: .zero, size: renderSize), blendMode: .normal, alpha: 0.6)

            guard !points.isEmpty else { return }

            // 骨骼连接
            let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })
            let path = UIBezierPath()
            path.lineWidth = max(renderSize.width, renderSize.height) * 0.004

            // 复用 SkeletonRenderer 的连接定义
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

            for (j1, j2) in connections {
                guard let p1 = dict[j1], let p2 = dict[j2],
                      p1.confidence > 0.3, p2.confidence > 0.3 else { continue }
                path.move(to: denorm(p1.location))
                path.addLine(to: denorm(p2.location))
            }
            UIColor.green.withAlphaComponent(0.7).setStroke()
            path.stroke()

            // 关节点
            for (_, p) in dict where p.confidence > 0.3 {
                let center = denorm(p.location)
                let radius = max(renderSize.width, renderSize.height) * 0.012
                let color: UIColor = p.confidence > 0.6
                    ? UIColor.green.withAlphaComponent(0.9)
                    : UIColor.yellow.withAlphaComponent(0.7)
                UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true).fillWith(color)
            }
        }
    }
}

private extension UIBezierPath {
    func fillWith(_ color: UIColor) {
        color.setFill()
        fill()
    }
}
