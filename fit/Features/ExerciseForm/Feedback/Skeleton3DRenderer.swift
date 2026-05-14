import SwiftUI
import AVFoundation

// MARK: - Skeleton Renderer (2D normalized coords, Vision origin bottom-left)

struct Skeleton3DRenderer {

    private static let connections: [(String, String)] = [
        ("neck_1_joint", "root"),
        ("neck_1_joint", "left_shoulder_1_joint"),
        ("neck_1_joint", "right_shoulder_1_joint"),
        ("root", "left_upLeg_joint"),
        ("root", "right_upLeg_joint"),
        ("left_shoulder_1_joint", "left_forearm_joint"),
        ("left_forearm_joint", "left_hand_joint"),
        ("right_shoulder_1_joint", "right_forearm_joint"),
        ("right_forearm_joint", "right_hand_joint"),
        ("left_upLeg_joint", "left_leg_joint"),
        ("left_leg_joint", "left_foot_joint"),
        ("right_upLeg_joint", "right_leg_joint"),
        ("right_leg_joint", "right_foot_joint"),
    ]

    private static let jointLabels: [String: String] = [
        "nose": "鼻",
        "left_eye_joint": "左眼",
        "right_eye_joint": "右眼",
        "left_ear_joint": "左耳",
        "right_ear_joint": "右耳",
        "neck_1_joint": "颈",
        "root": "髋",
        "left_shoulder_1_joint": "左肩",
        "right_shoulder_1_joint": "右肩",
        "left_forearm_joint": "左肘",
        "right_forearm_joint": "右肘",
        "left_hand_joint": "左腕",
        "right_hand_joint": "右腕",
        "left_upLeg_joint": "左髋",
        "right_upLeg_joint": "右髋",
        "left_leg_joint": "左膝",
        "right_leg_joint": "右膝",
        "left_foot_joint": "左踝",
        "right_foot_joint": "右踝",
    ]

    // Temporal smoothing state
    @MainActor private static var smoothedPositions: [String: CGPoint] = [:]
    private static let smoothingFactor: CGFloat = 0.35

    @MainActor
    static func draw(
        context: inout GraphicsContext,
        joints: BodyJoints,
        canvasSize: CGSize,
        isFrontCamera: Bool = false
    ) {
        let jointMap = buildJointMap(joints: joints, canvasSize: canvasSize, isFrontCamera: isFrontCamera)

        // Bones
        for (a, b) in connections {
            guard let ja = jointMap[a], let jb = jointMap[b] else { continue }
            let midZ = (ja.z + jb.z) / 2
            let opacity = depthOpacity(midZ)
            var path = Path()
            path.move(to: ja.point)
            path.addLine(to: jb.point)
            context.stroke(path, with: .color(.green.opacity(opacity)),
                          style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Joint dots + labels
        for (name, data) in jointMap {
            let opacity = depthOpacity(data.z)
            let r: CGFloat = 5
            let dotRect = CGRect(x: data.point.x - r, y: data.point.y - r, width: r*2, height: r*2)
            context.fill(Path(ellipseIn: dotRect), with: .color(.green.opacity(opacity)))

            let label = jointLabels[name] ?? shortName(name)
            let text = Text(label)
                .font(.system(size: 11).bold())
                .foregroundColor(.white.opacity(opacity))
            context.draw(text, at: CGPoint(x: data.point.x + 8, y: data.point.y - 8), anchor: .leading)
        }
    }

    // MARK: - Joint map building (shared between Canvas draw and video recording)

    private static func buildJointMap(
        joints: BodyJoints,
        canvasSize: CGSize,
        isFrontCamera: Bool
    ) -> [String: (point: CGPoint, z: Float)] {
        var map: [String: (point: CGPoint, z: Float)] = [:]

        for j in joints {
            guard j.location2D != .zero else { continue }
            let vx = isFrontCamera ? (1.0 - j.location2D.x) : j.location2D.x
            let rawPoint = CGPoint(
                x: vx * canvasSize.width,
                y: (1.0 - j.location2D.y) * canvasSize.height
            )

            // Temporal smoothing
            let prev = smoothedPositions[j.joint] ?? rawPoint
            let smoothed = CGPoint(
                x: prev.x + (rawPoint.x - prev.x) * smoothingFactor,
                y: prev.y + (rawPoint.y - prev.y) * smoothingFactor
            )
            smoothedPositions[j.joint] = smoothed

            let z = j.position3D?.z ?? 2.0
            map[j.joint] = (smoothed, z)
        }
        return map
    }

    // MARK: - Off-screen rendering for video recording

    /// Render skeleton onto a CGContext (for video frame compositing).
    /// Uses the same coordinate logic as Canvas draw.
    static func renderOntoContext(
        _ ctx: CGContext,
        joints: BodyJoints,
        imageSize: CGSize,
        isFrontCamera: Bool
    ) {
        // Reset smoothing for recording (separate from display smoothing)
        var map: [String: (point: CGPoint, z: Float)] = [:]

        for j in joints {
            guard j.location2D != .zero else { continue }
            let vx = isFrontCamera ? (1.0 - j.location2D.x) : j.location2D.x
            let point = CGPoint(
                x: vx * imageSize.width,
                y: (1.0 - j.location2D.y) * imageSize.height
            )
            let z = j.position3D?.z ?? 2.0
            map[j.joint] = (point, z)
        }

        // Bones
        for (a, b) in connections {
            guard let ja = map[a], let jb = map[b] else { continue }
            let midZ = (ja.z + jb.z) / 2
            let alpha = CGFloat(depthOpacity(midZ))
            ctx.setStrokeColor(UIColor.green.withAlphaComponent(alpha).cgColor)
            ctx.setLineWidth(3)
            ctx.setLineCap(.round)
            ctx.move(to: ja.point)
            ctx.addLine(to: jb.point)
            ctx.strokePath()
        }

        // Joint dots
        for (_, data) in map {
            let r: CGFloat = 5
            let alpha = CGFloat(depthOpacity(data.z))
            ctx.setFillColor(UIColor.green.withAlphaComponent(alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: data.point.x - r, y: data.point.y - r,
                                        width: r * 2, height: r * 2))
        }

        // Text labels
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.white,
        ]
        UIGraphicsPushContext(ctx)
        for (name, data) in map {
            let label = jointLabels[name] ?? shortName(name)
            let alpha = CGFloat(depthOpacity(data.z))
            let str = NSAttributedString(string: label, attributes: [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.white.withAlphaComponent(alpha),
            ])
            str.draw(at: CGPoint(x: data.point.x + 8, y: data.point.y - 8))
        }
        UIGraphicsPopContext()
    }

    private static func shortName(_ raw: String) -> String {
        String(raw.split(separator: "_").first ?? Substring(raw))
    }

    private static func depthOpacity(_ z: Float) -> Double {
        let clamped = max(0.5, min(z, 5.0))
        return Double(1.0 - (clamped - 0.5) / 4.5 * 0.5)
    }
}
