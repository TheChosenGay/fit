import Foundation

enum AngleCalculator {
    private enum Joint: String {
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

    static func compute(_ points: [PosePoint], cgImageSize: CGSize) -> PoseAngle {
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })

        func physical(_ j: Joint) -> CGPoint? {
            guard let p = dict[j.rawValue] else { return nil }
            return CGPoint(x: p.location.x * cgImageSize.width,
                           y: p.location.y * cgImageSize.height)
        }

        guard let neck = physical(.neck), let root = physical(.root) else {
            print("[AngleCalculator] ⚠️ 缺少 neck 或 root 关键点，无法计算")
            return PoseAngle()
        }

        // 身体中轴方向 (neck → root 的反方向，即脚→头的方向)
        let axisDX = neck.x - root.x
        let axisDY = neck.y - root.y
        let axisLen = hypot(axisDX, axisDY)
        guard axisLen > 10 else {
            print("[AngleCalculator] ⚠️ 身体中轴太短 (\(axisLen) px)，无法计算")
            return PoseAngle()
        }

        // 身体中轴与水平面的夹角（度）
        let bodyAngleDeg = atan2(axisDY, axisDX) * 180 / .pi

        // 计算某条线段相对身体中轴的偏移角度
        // 返回: 线段与身体中轴法线（即水平线）的夹角
        func tiltAngle(from j1: Joint, to j2: Joint) -> Float? {
            guard let a = physical(j1), let b = physical(j2) else { return nil }
            let dx = b.x - a.x
            let dy = b.y - a.y
            let lineAngle = atan2(dy, dx) * 180 / .pi
            // 线段与身体中轴的夹角，然后转成与水平面的夹角
            let relative = abs(lineAngle - bodyAngleDeg)
            return Float(min(relative, 180 - relative))
        }

        // 水平偏移（像素），沿身体水平方向的分量
        func lateralDiff(between j1: Joint, and j2: Joint) -> Float? {
            guard let a = physical(j1), let b = physical(j2) else { return nil }
            let dx = b.x - a.x
            let dy = b.y - a.y
            // 投影到身体中轴的法线方向（即身体的水平方向）
            let normalX = -axisDY / axisLen
            let normalY = axisDX / axisLen
            return Float(abs(dx * normalX + dy * normalY))
        }

        let result = PoseAngle(
            // 头部侧倾：两耳连线相对于水平的角度
            headForward: tiltAngle(from: .leftEar, to: .rightEar),
            // 高低肩：两肩沿身体垂直方向的像素差
            shoulderDiff: {
                guard let ls = physical(.leftShoulder), let rs = physical(.rightShoulder) else { return nil }
                let unitX = axisDX / axisLen
                let unitY = axisDY / axisLen
                let leftProj = ls.x * unitX + ls.y * unitY
                let rightProj = rs.x * unitX + rs.y * unitY
                return Float(abs(leftProj - rightProj))
            }(),
            // 圆肩 → 改为测量肩部水平倾斜角度
            roundShoulder: tiltAngle(from: .leftShoulder, to: .rightShoulder),
            // 骨盆倾斜：两髋连线相对于水平的角度
            pelvicTilt: tiltAngle(from: .leftHip, to: .rightHip),
            // 腿型：膝盖偏离髋-踝连线的距离（像素）
            legAlignment: {
                let hip: Joint = dict[Joint.rightHip.rawValue]?.confidence ?? 0 > (dict[Joint.leftHip.rawValue]?.confidence ?? 0) ? .rightHip : .leftHip
                let knee: Joint = dict[Joint.rightKnee.rawValue]?.confidence ?? 0 > (dict[Joint.leftKnee.rawValue]?.confidence ?? 0) ? .rightKnee : .leftKnee
                let ankle: Joint = dict[Joint.rightAnkle.rawValue]?.confidence ?? 0 > (dict[Joint.leftAnkle.rawValue]?.confidence ?? 0) ? .rightAnkle : .leftAnkle
                guard let hip = physical(hip), let knee = physical(knee), let ankle = physical(ankle) else { return nil }
                let dx = ankle.x - hip.x
                let dy = ankle.y - hip.y
                let lenSq = dx * dx + dy * dy
                guard lenSq > 0 else { return nil }
                let t = max(0, min(1, ((knee.x - hip.x) * dx + (knee.y - hip.y) * dy) / lenSq))
                let projX = hip.x + t * dx
                let projY = hip.y + t * dy
                return Float(hypot(knee.x - projX, knee.y - projY))
            }()
        )

        print("[AngleCalculator] 📐 身体中轴角度=\(String(format: "%.1f", bodyAngleDeg))° (len=\(Int(axisLen))px)")
        print("[AngleCalculator]   头部侧倾(ear→ear): \(result.headForward.map { String(format: "%.1f°", $0) } ?? "nil")")
        print("[AngleCalculator]   高低肩(垂直差): \(result.shoulderDiff.map { String(format: "%.1f px", $0) } ?? "nil")")
        print("[AngleCalculator]   肩部倾斜(shoulder→shoulder): \(result.roundShoulder.map { String(format: "%.1f°", $0) } ?? "nil")")
        print("[AngleCalculator]   骨盆倾斜(hip→hip): \(result.pelvicTilt.map { String(format: "%.1f°", $0) } ?? "nil")")
        print("[AngleCalculator]   腿型(膝偏移): \(result.legAlignment.map { String(format: "%.1f px", $0) } ?? "nil")")

        return result
    }
}
