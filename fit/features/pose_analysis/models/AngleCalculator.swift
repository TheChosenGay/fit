import Foundation

enum AngleCalculator {
    private enum Joint: String {
        case nose
        case leftEye
        case rightEye
        case leftEar
        case rightEar
        case neck
        case root
        case leftShoulder
        case rightShoulder
        case leftElbow
        case rightElbow
        case leftWrist
        case rightWrist
        case leftHip
        case rightHip
        case leftKnee
        case rightKnee
        case leftAnkle
        case rightAnkle
    }

    static func compute(_ points: [PosePoint]) -> PoseAngle {
        let dict = Dictionary(uniqueKeysWithValues: points.map { ($0.joint, $0) })

        func point(_ j: Joint) -> CGPoint? {
            dict[j.rawValue].map { $0.location }
        }

        return PoseAngle(
            headForward: angleFromVertical(
                from: point(.rightEar) ?? point(.leftEar),
                to: point(.rightShoulder) ?? point(.leftShoulder)
            ),
            shoulderDiff: shoulderDiff(
                left: point(.leftShoulder), right: point(.rightShoulder)
            ),
            roundShoulder: angleFromVertical(
                from: point(.rightShoulder) ?? point(.leftShoulder),
                to: point(.rightEar) ?? point(.leftEar)
            ),
            pelvicTilt: angleFromVertical(
                from: point(.rightHip) ?? point(.leftHip),
                to: point(.rightKnee) ?? point(.leftKnee)
            ),
            legAlignment: legOffset(
                hip: point(.rightHip) ?? point(.leftHip),
                knee: point(.rightKnee) ?? point(.leftKnee),
                ankle: point(.rightAnkle) ?? point(.leftAnkle)
            )
        )
    }

    // MARK: - Angle from vertical

    private static func angleFromVertical(from: CGPoint?, to: CGPoint?) -> Float? {
        guard let from, let to else { return nil }
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = hypot(dx, dy)
        guard length > 0 else { return nil }
        return Float(atan2(abs(dx), abs(dy)) * 180 / .pi)
    }

    // MARK: - Shoulder level difference

    private static func shoulderDiff(left: CGPoint?, right: CGPoint?) -> Float? {
        guard let left, let right else { return nil }
        return Float(abs(left.y - right.y))
    }

    // MARK: - Leg alignment offset

    private static func legOffset(hip: CGPoint?, knee: CGPoint?, ankle: CGPoint?) -> Float? {
        guard let hip, let knee, let ankle else { return nil }
        let dx = ankle.x - hip.x
        let dy = ankle.y - hip.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return nil }
        let t = max(0, min(1, ((knee.x - hip.x) * dx + (knee.y - hip.y) * dy) / lenSq))
        let projX = hip.x + t * dx
        let projY = hip.y + t * dy
        return Float(hypot(knee.x - projX, knee.y - projY))
    }
}
