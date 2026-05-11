import UIKit

enum SkeletonRenderer {
    private enum Joint: String, CaseIterable {
        case leftEar = "left_ear_joint"
        case rightEar = "right_ear_joint"
        case neck = "neck_1_joint"
        case root = "root"
        case leftShoulder = "left_shoulder_1_joint"
        case rightShoulder = "right_shoulder_1_joint"
        case leftElbow = "left_forearm_joint"
        case rightElbow = "right_forearm_joint"
        case leftWrist = "left_hand_joint"
        case rightWrist = "right_hand_joint"
        case leftHip = "left_upLeg_joint"
        case rightHip = "right_upLeg_joint"
        case leftKnee = "left_leg_joint"
        case rightKnee = "right_leg_joint"
        case leftAnkle = "left_foot_joint"
        case rightAnkle = "right_foot_joint"
    }

    private static let connections: [(Joint, Joint)] = [
        (.leftEar, .neck),
        (.rightEar, .neck),
        (.neck, .leftShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.neck, .rightShoulder), (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.root, .rightHip), (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.leftShoulder, .rightShoulder),
        (.leftHip, .rightHip),
    ]

    static func render(image: UIImage, points: [PosePoint], angles: PoseAngle? = nil, cgImageSize: CGSize? = nil) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })
        let renderSize = cgImageSize ?? CGSize(width: cgImage.width, height: cgImage.height)
        let landscape = renderSize.width > renderSize.height
        let lineWidth = max(renderSize.width, renderSize.height) * 0.003
        let fontSize = max(renderSize.width, renderSize.height) * 0.025

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let annotatedCGImage = renderer.image { ctx in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: renderSize))

            func denorm(_ p: CGPoint) -> CGPoint {
                CGPoint(x: p.x * renderSize.width, y: (1.0 - p.y) * renderSize.height)
            }

            // ── Skeleton connections (white) ──
            let path = UIBezierPath()
            path.lineWidth = lineWidth
            for (j1, j2) in connections {
                guard let p1 = dict[j1.rawValue], let p2 = dict[j2.rawValue],
                      p1.confidence > 0.3, p2.confidence > 0.3 else { continue }
                path.move(to: denorm(p1.location))
                path.addLine(to: denorm(p2.location))
            }
            UIColor.white.withAlphaComponent(0.8).setStroke()
            path.stroke()

            // ── Joint dots ──
            for (_, point) in dict where point.confidence > 0.3 {
                let center = denorm(point.location)
                let radius = max(renderSize.width, renderSize.height) * 0.008
                let color: UIColor = point.confidence > 0.6
                    ? UIColor.green.withAlphaComponent(0.9)
                    : UIColor.yellow.withAlphaComponent(0.8)
                UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true).fillWith(color)
            }

            // ── Measurement annotations ──
            guard let angles else {
                // No angle data, skip annotations
                return
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor.white,
            ]
            let bgAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor.black.withAlphaComponent(0.5),
            ]

            func annotate(lineFrom j1: Joint, to j2: Joint, label: String, color: UIColor, offset: CGPoint) {
                guard let p1 = dict[j1.rawValue], let p2 = dict[j2.rawValue],
                      p1.confidence > 0.3, p2.confidence > 0.3 else { return }
                let a = denorm(p1.location)
                let b = denorm(p2.location)
                let mid = CGPoint(x: (a.x + b.x) / 2 + offset.x,
                                  y: (a.y + b.y) / 2 + offset.y)

                // measurement line
                let measurePath = UIBezierPath()
                measurePath.lineWidth = lineWidth * 1.5
                measurePath.move(to: a)
                measurePath.addLine(to: b)
                color.withAlphaComponent(0.6).setStroke()
                measurePath.stroke()

                // label background
                let text = label as NSString
                let textSize = text.size(withAttributes: attrs)
                let textRect = CGRect(x: mid.x - textSize.width / 2 - 6,
                                       y: mid.y - textSize.height / 2 - 4,
                                       width: textSize.width + 12,
                                       height: textSize.height + 8)
                let bgPath = UIBezierPath(roundedRect: textRect, cornerRadius: 4)
                UIColor.black.withAlphaComponent(0.55).setFill()
                bgPath.fill()

                text.draw(at: CGPoint(x: textRect.origin.x + 6, y: textRect.origin.y + 4), withAttributes: attrs)
            }

            // 头部侧倾: ear → ear
            if let ang = angles.headForward,
               let le = dict[Joint.leftEar.rawValue], let re = dict[Joint.rightEar.rawValue],
               le.confidence > 0.3, re.confidence > 0.3 {
                annotate(lineFrom: .leftEar, to: .rightEar, label: String(format: "头部侧倾 %.1f°", ang), color: .cyan,
                         offset: CGPoint(x: 0, y: -40))
            }

            // 肩部倾斜: shoulder → shoulder
            if let ang = angles.roundShoulder,
               let ls = dict[Joint.leftShoulder.rawValue], let rs = dict[Joint.rightShoulder.rawValue],
               ls.confidence > 0.3, rs.confidence > 0.3 {
                annotate(lineFrom: .leftShoulder, to: .rightShoulder, label: String(format: "肩部倾斜 %.1f°", ang), color: .orange,
                         offset: CGPoint(x: 0, y: -30))
            }

            // shoulderDiff
            if let diff = angles.shoulderDiff,
               let ls = dict[Joint.leftShoulder.rawValue], let rs = dict[Joint.rightShoulder.rawValue],
               ls.confidence > 0.3, rs.confidence > 0.3 {
                let a = denorm(ls.location)
                let b = denorm(rs.location)
                let mid = CGPoint(x: (a.x + b.x) / 2, y: a.y - 30)

                let measurePath = UIBezierPath()
                measurePath.lineWidth = lineWidth * 1.5
                measurePath.move(to: a)
                measurePath.addLine(to: b)
                UIColor.yellow.withAlphaComponent(0.6).setStroke()
                measurePath.stroke()

                let text = String(format: "高低肩 %.0fpx", diff) as NSString
                let textSize = text.size(withAttributes: attrs)
                let textRect = CGRect(x: mid.x - textSize.width / 2 - 6,
                                       y: mid.y - textSize.height / 2 - 4,
                                       width: textSize.width + 12, height: textSize.height + 8)
                UIBezierPath(roundedRect: textRect, cornerRadius: 4).fillWith(UIColor.black.withAlphaComponent(0.55))
                text.draw(at: CGPoint(x: textRect.origin.x + 6, y: textRect.origin.y + 4), withAttributes: attrs)
            }

            // 骨盆倾斜: hip → hip
            if let ang = angles.pelvicTilt,
               let lh = dict[Joint.leftHip.rawValue], let rh = dict[Joint.rightHip.rawValue],
               lh.confidence > 0.3, rh.confidence > 0.3 {
                annotate(lineFrom: .leftHip, to: .rightHip, label: String(format: "骨盆倾斜 %.1f°", ang), color: .magenta,
                         offset: CGPoint(x: 0, y: 30))
            }

            // legAlignment: knee deviation
            if let off = angles.legAlignment {
                let knee: Joint = dict[Joint.rightKnee.rawValue]?.confidence ?? 0 > (dict[Joint.leftKnee.rawValue]?.confidence ?? 0) ? .rightKnee : .leftKnee
                if let pk = dict[knee.rawValue], pk.confidence > 0.3 {
                    let k = denorm(pk.location)
                    let text = String(format: "腿型 %.0fpx", off) as NSString
                    let textSize = text.size(withAttributes: attrs)
                    let textRect = CGRect(x: k.x - textSize.width / 2 - 6,
                                           y: k.y - textSize.height - 12,
                                           width: textSize.width + 12, height: textSize.height + 8)
                    UIBezierPath(roundedRect: textRect, cornerRadius: 4).fillWith(UIColor.black.withAlphaComponent(0.55))
                    text.draw(at: CGPoint(x: textRect.origin.x + 6, y: textRect.origin.y + 4), withAttributes: attrs)
                }
            }
        }.cgImage!

        return UIImage(cgImage: annotatedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

private extension UIBezierPath {
    func fillWith(_ color: UIColor) {
        color.setFill()
        fill()
    }
}
