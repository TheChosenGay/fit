import UIKit

enum SkeletonRenderer {

    private static let connections: [(String, String)] = [
        // Body (15)
        ("left_ear_joint", "neck_1_joint"),
        ("right_ear_joint", "neck_1_joint"),
        ("neck_1_joint", "left_shoulder_1_joint"),
        ("left_shoulder_1_joint", "left_forearm_joint"),
        ("left_forearm_joint", "left_hand_joint"),
        ("neck_1_joint", "right_shoulder_1_joint"),
        ("right_shoulder_1_joint", "right_forearm_joint"),
        ("right_forearm_joint", "right_hand_joint"),
        ("neck_1_joint", "root"),
        ("root", "left_upLeg_joint"),
        ("left_upLeg_joint", "left_leg_joint"),
        ("left_leg_joint", "left_foot_joint"),
        ("root", "right_upLeg_joint"),
        ("right_upLeg_joint", "right_leg_joint"),
        ("right_leg_joint", "right_foot_joint"),
        ("left_shoulder_1_joint", "right_shoulder_1_joint"),
        ("left_upLeg_joint", "right_upLeg_joint"),
        // Feet (6)
        ("left_foot_joint", "left_big_toe"),
        ("left_foot_joint", "left_small_toe"),
        ("left_foot_joint", "left_heel"),
        ("right_foot_joint", "right_big_toe"),
        ("right_foot_joint", "right_small_toe"),
        ("right_foot_joint", "right_heel"),
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

    nonisolated static func render(image: UIImage, points: [PosePoint]) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })
        let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
        let lineWidth = max(cgSize.width, cgSize.height) * 0.003

        let renderer = UIGraphicsImageRenderer(size: cgSize)
        let annotatedCGImage = renderer.image { ctx in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: cgSize))

            func denorm(_ p: CGPoint) -> CGPoint {
                CGPoint(x: p.x * cgSize.width, y: (1.0 - p.y) * cgSize.height)
            }

            // Skeleton lines
            let path = UIBezierPath()
            path.lineWidth = lineWidth
            for (a, b) in connections {
                guard let p1 = dict[a], let p2 = dict[b],
                      p1.confidence > 0.3, p2.confidence > 0.3 else { continue }
                path.move(to: denorm(p1.location))
                path.addLine(to: denorm(p2.location))
            }
            UIColor.white.withAlphaComponent(0.8).setStroke()
            path.stroke()

            // Joint dots
            for (_, point) in dict where point.confidence > 0.3 {
                let center = denorm(point.location)
                let radius = max(cgSize.width, cgSize.height) * 0.008
                let color: UIColor = point.confidence > 0.6
                    ? UIColor.green.withAlphaComponent(0.9)
                    : UIColor.yellow.withAlphaComponent(0.8)
                let circle = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                color.setFill()
                circle.fill()
            }
        }.cgImage!

        return UIImage(cgImage: annotatedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
