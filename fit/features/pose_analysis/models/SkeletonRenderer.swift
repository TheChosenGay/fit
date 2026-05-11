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

    static func render(image: UIImage, points: [PosePoint]) -> UIImage {
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })
        let imageSize = image.size

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { ctx in
            image.draw(at: .zero)

            let path = UIBezierPath()
            path.lineWidth = max(imageSize.width, imageSize.height) * 0.003

            for (j1, j2) in connections {
                guard let p1 = dict[j1.rawValue], let p2 = dict[j2.rawValue],
                      p1.confidence > 0.3, p2.confidence > 0.3 else { continue }
                let from = denormalize(p1.location, to: imageSize)
                let to = denormalize(p2.location, to: imageSize)
                path.move(to: from)
                path.addLine(to: to)
            }

            UIColor.white.withAlphaComponent(0.8).setStroke()
            path.stroke()

            for (_, point) in dict where point.confidence > 0.3 {
                let center = denormalize(point.location, to: imageSize)
                let radius = max(imageSize.width, imageSize.height) * 0.008
                let color: UIColor = point.confidence > 0.6
                    ? UIColor.green.withAlphaComponent(0.9)
                    : UIColor.yellow.withAlphaComponent(0.8)
                let circle = UIBezierPath(
                    arcCenter: center, radius: radius,
                    startAngle: 0, endAngle: .pi * 2, clockwise: true
                )
                color.setFill()
                circle.fill()
            }
        }
    }

    private static func denormalize(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
