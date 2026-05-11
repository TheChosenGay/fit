import Foundation

enum ViewAngle: String {
    case front  // 正面/背面
    case side   // 侧面
}

enum AngleCalculator {
    private enum Joint: String {
        case leftEar = "left_ear_joint"
        case rightEar = "right_ear_joint"
        case leftEye = "left_eye_joint"
        case rightEye = "right_eye_joint"
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

    struct Result {
        let angle: PoseAngle
        let viewAngle: ViewAngle
    }

    static func compute(_ points: [PosePoint], cgImageSize: CGSize) -> Result {
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })

        func physical(_ j: Joint) -> CGPoint? {
            guard let p = dict[j.rawValue] else { return nil }
            return CGPoint(x: p.location.x * cgImageSize.width,
                           y: p.location.y * cgImageSize.height)
        }

        func confidence(_ j: Joint) -> Float {
            dict[j.rawValue]?.confidence ?? 0
        }

        guard let neck = physical(.neck), let root = physical(.root) else {
            print("[AngleCalculator] ⚠️ 缺少 neck 或 root，无法计算")
            return Result(angle: PoseAngle(), viewAngle: .front)
        }

        // 身体中轴 (root → neck)
        let axisDX = neck.x - root.x
        let axisDY = neck.y - root.y
        let axisLen = hypot(axisDX, axisDY)
        guard axisLen > 10 else {
            print("[AngleCalculator] ⚠️ 身体中轴太短，无法计算")
            return Result(angle: PoseAngle(), viewAngle: .front)
        }

        // ── 判断视角：对比左右侧检测到的关节数量 ──
        let leftPairs: [Joint] = [.leftEar, .leftEye, .leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftKnee, .leftAnkle]
        let rightPairs: [Joint] = [.rightEar, .rightEye, .rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightKnee, .rightAnkle]

        let leftCount = leftPairs.filter { confidence($0) > 0.3 }.count
        let rightCount = rightPairs.filter { confidence($0) > 0.3 }.count
        let totalCount = leftCount + rightCount

        // 如果一侧关节数明显多于另一侧（>2倍差），判定为侧面
        let viewAngle: ViewAngle = {
            if leftCount == 0 && rightCount == 0 { return .front }
            let ratio = totalCount > 0 ? Float(max(leftCount, rightCount)) / Float(totalCount) : 0.5
            return ratio > 0.75 ? .side : .front
        }()

        let bodyAngleDeg = atan2(axisDY, axisDX) * 180 / .pi

        // 线段与身体中轴的锐角 [0, 90]
        func acuteAngleToAxis(from j1: Joint, to j2: Joint) -> Float? {
            guard let a = physical(j1), let b = physical(j2) else { return nil }
            let dx = b.x - a.x
            let dy = b.y - a.y
            var rel = abs(atan2(dy, dx) * 180 / .pi - bodyAngleDeg)
            rel = min(rel, 180 - rel)
            return Float(rel)
        }

        // 水平方向倾斜：偏离垂直中轴法线(90°)的量
        func horizontalTilt(from j1: Joint, to j2: Joint) -> Float? {
            guard let acute = acuteAngleToAxis(from: j1, to: j2) else { return nil }
            return abs(90 - acute)
        }

        // 垂直方向倾斜：偏离垂直中轴的量
        func verticalTilt(from j1: Joint, to j2: Joint) -> Float? {
            acuteAngleToAxis(from: j1, to: j2)
        }

        // 沿身体垂直方向的高差投影 (px)
        func verticalProjectionDiff(between j1: Joint, and j2: Joint) -> Float? {
            guard let a = physical(j1), let b = physical(j2) else { return nil }
            let ux = axisDX / axisLen
            let uy = axisDY / axisLen
            return Float(abs((a.x - b.x) * ux + (a.y - b.y) * uy))
        }

        // ── 根据视角计算不同指标 ──
        let angle: PoseAngle

        switch viewAngle {
        case .front:
            angle = PoseAngle(
                headForward: horizontalTilt(from: .leftEar, to: .rightEar),
                shoulderDiff: verticalProjectionDiff(between: .leftShoulder, and: .rightShoulder),
                roundShoulder: horizontalTilt(from: .leftShoulder, to: .rightShoulder),
                pelvicTilt: horizontalTilt(from: .leftHip, to: .rightHip),
                legAlignment: {
                    guard let hip = physical(.rightHip) ?? physical(.leftHip),
                          let knee = physical(.rightKnee) ?? physical(.leftKnee),
                          let ankle = physical(.rightAnkle) ?? physical(.leftAnkle) else { return nil }
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

        case .side:
            // 侧面可以测：耳→肩（头前伸）、肩→髋（圆肩）、髋→膝（骨盆前倾）、膝角度
            let ear: Joint = confidence(.rightEar) > confidence(.leftEar) ? .rightEar : .leftEar
            let shoulder: Joint = confidence(.rightShoulder) > confidence(.leftShoulder) ? .rightShoulder : .leftShoulder
            let hip: Joint = confidence(.rightHip) > confidence(.leftHip) ? .rightHip : .leftHip
            let knee: Joint = confidence(.rightKnee) > confidence(.leftKnee) ? .rightKnee : .leftKnee
            let ankle: Joint = confidence(.rightAnkle) > confidence(.leftAnkle) ? .rightAnkle : .leftAnkle

            angle = PoseAngle(
                // 头前伸：耳→肩偏离垂直的角度
                headForward: verticalTilt(from: ear, to: shoulder),
                // 高低肩 → 侧面改用 肩→髋 垂直偏移衡量驼背/圆肩
                shoulderDiff: verticalProjectionDiff(between: shoulder, and: hip),
                // 圆肩 → 肩→髋 偏离垂直的角度
                roundShoulder: verticalTilt(from: shoulder, to: hip),
                // 骨盆前倾：髋→膝 偏离垂直
                pelvicTilt: verticalTilt(from: hip, to: knee),
                // 腿型 → 膝超伸角度
                legAlignment: {
                    guard let hip = physical(hip), let knee = physical(knee), let ankle = physical(ankle) else { return nil }
                    // 计算膝关节角度 (髋→膝→踝)
                    let vec1x = hip.x - knee.x
                    let vec1y = hip.y - knee.y
                    let vec2x = ankle.x - knee.x
                    let vec2y = ankle.y - knee.y
                    let dot = vec1x * vec2x + vec1y * vec2y
                    let mag1 = hypot(vec1x, vec1y)
                    let mag2 = hypot(vec2x, vec2y)
                    guard mag1 > 0, mag2 > 0 else { return nil }
                    let kneeAngle = acos(max(-1, min(1, dot / (mag1 * mag2)))) * 180 / .pi
                    return Float(kneeAngle)
                }()
            )
        }

        print("[AngleCalculator] 📐 视角=\(viewAngle.rawValue) (左\(leftCount) 右\(rightCount)) 中轴=\(String(format: "%.1f", bodyAngleDeg))°")
        print("[AngleCalculator]   头前伸/侧倾: \(angle.headForward.map { String(format: "%.1f°", $0) } ?? "nil")")
        print("[AngleCalculator]   高低肩/驼背: \(angle.shoulderDiff.map { String(format: "%.1f px", $0) } ?? "nil")")
        print("[AngleCalculator]   圆肩/肩倾斜: \(angle.roundShoulder.map { String(format: "%.1f°", $0) } ?? "nil")")
        print("[AngleCalculator]   骨盆倾斜/前倾: \(angle.pelvicTilt.map { String(format: "%.1f°", $0) } ?? "nil")")
        print("[AngleCalculator]   腿型/膝角度: \(angle.legAlignment.map { String(format: "%.1f", $0) } ?? "nil")")

        return Result(angle: angle, viewAngle: viewAngle)
    }
}
