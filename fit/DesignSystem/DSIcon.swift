import SwiftUI

// MARK: - Icon Weight

enum DSIconWeight: CGFloat, CaseIterable {
    case light   = 1.0
    case regular = 1.5
    case medium  = 2.0
    case bold    = 2.5

    var name: String {
        switch self {
        case .light:   return "Light"
        case .regular: return "Regular"
        case .medium:  return "Medium"
        case .bold:    return "Bold"
        }
    }
}

// MARK: - Icon Name

enum DSIconName: String, CaseIterable {
    case camera
    case activity
    case history
    case settings
    case user
    case share
    case checkCircle
    case alertTriangle
}

// MARK: - DSIcon View

@available(iOS 15.0, *)
struct DSIcon: View {
    let name: DSIconName
    var weight: DSIconWeight = .regular
    var size: CGFloat = 24

    var body: some View {
        DSIconShape(name: name)
            .stroke(style: StrokeStyle(
                lineWidth: weight.rawValue,
                lineCap: .round,
                lineJoin: .round
            ))
            .frame(width: size, height: size)
    }
}

// MARK: - Icon Shape (Path drawings)

private struct DSIconShape: Shape {
    let name: DSIconName

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()

        switch name {
        case .camera:
            drawCamera(&path, scale: s, in: rect)
        case .activity:
            drawActivity(&path, scale: s, in: rect)
        case .history:
            drawHistory(&path, scale: s, in: rect)
        case .settings:
            drawSettings(&path, scale: s, in: rect)
        case .user:
            drawUser(&path, scale: s, in: rect)
        case .share:
            drawShare(&path, scale: s, in: rect)
        case .checkCircle:
            drawCheckCircle(&path, scale: s, in: rect)
        case .alertTriangle:
            drawAlertTriangle(&path, scale: s, in: rect)
        }
        return path
    }

    // MARK: - Camera
    private func drawCamera(_ path: inout Path, scale s: CGFloat, in rect: CGRect) {
        path.addRoundedRect(
            in: CGRect(x: 2*s, y: 7*s, width: 20*s, height: 13*s),
            cornerSize: CGSize(width: 2*s, height: 2*s)
        )
        path.move(to: CGPoint(x: 8.5*s, y: 7*s))
        path.addLine(to: CGPoint(x: 9.5*s, y: 4.5*s))
        path.addLine(to: CGPoint(x: 14.5*s, y: 4.5*s))
        path.addLine(to: CGPoint(x: 15.5*s, y: 7*s))
        let center = CGPoint(x: 12*s, y: 13.5*s)
        path.addEllipse(in: CGRect(
            x: center.x - 3*s, y: center.y - 3*s,
            width: 6*s, height: 6*s
        ))
    }

    // MARK: - Activity (heart rate / pulse)
    private func drawActivity(_ path: inout Path, scale s: CGFloat, in rect: CGRect) {
        path.move(to: CGPoint(x: 2*s, y: 12*s))
        path.addLine(to: CGPoint(x: 5.5*s, y: 12*s))
        path.addLine(to: CGPoint(x: 8*s, y: 3*s))
        path.addLine(to: CGPoint(x: 12*s, y: 21*s))
        path.addLine(to: CGPoint(x: 15*s, y: 8*s))
        path.addLine(to: CGPoint(x: 18.5*s, y: 12*s))
        path.addLine(to: CGPoint(x: 22*s, y: 12*s))
    }

    // MARK: - History (clock with arrow)
    private func drawHistory(_ path: inout Path, scale s: CGFloat, in rect: CGRect) {
        let center = CGPoint(x: 12*s, y: 12*s)
        path.addEllipse(in: CGRect(
            x: center.x - 9*s, y: center.y - 9*s,
            width: 18*s, height: 18*s
        ))
        path.move(to: center)
        path.addLine(to: CGPoint(x: 12*s, y: 8*s))
        path.move(to: center)
        path.addLine(to: CGPoint(x: 16*s, y: 12*s))
    }

    // MARK: - Settings (gear)
    private func drawSettings(_ path: inout Path, scale s: CGFloat, in rect: CGRect) {
        let center = CGPoint(x: 12*s, y: 12*s)
        path.addEllipse(in: CGRect(
            x: center.x - 3*s, y: center.y - 3*s,
            width: 6*s, height: 6*s
        ))
        let teeth = 8
        let outerR = 10.0 * s
        let innerR = 7.5 * s
        for i in 0..<teeth {
            let angle1 = Double(i) * .pi * 2 / Double(teeth) - .pi / 2
            let angle2 = angle1 + .pi * 2 / Double(teeth) * 0.35
            let angle3 = angle1 + .pi * 2 / Double(teeth) * 0.65
            let angle4 = angle1 + .pi * 2 / Double(teeth)
            let p1 = CGPoint(x: center.x + CGFloat(cos(angle1)) * innerR, y: center.y + CGFloat(sin(angle1)) * innerR)
            let p2 = CGPoint(x: center.x + CGFloat(cos(angle2)) * outerR, y: center.y + CGFloat(sin(angle2)) * outerR)
            let p3 = CGPoint(x: center.x + CGFloat(cos(angle3)) * outerR, y: center.y + CGFloat(sin(angle3)) * outerR)
            let p4 = CGPoint(x: center.x + CGFloat(cos(angle4)) * innerR, y: center.y + CGFloat(sin(angle4)) * innerR)
            if i == 0 { path.move(to: p1) }
            else { path.addLine(to: p1) }
            path.addLine(to: p2)
            path.addLine(to: p3)
            path.addLine(to: p4)
        }
        path.closeSubpath()
    }

    // MARK: - User
    private func drawUser(_ path: inout Path, scale s: CGFloat, in rect: CGRect) {
        path.addEllipse(in: CGRect(x: 8*s, y: 2*s, width: 8*s, height: 8*s))
        path.move(to: CGPoint(x: 2*s, y: 21*s))
        path.addQuadCurve(
            to: CGPoint(x: 22*s, y: 21*s),
            control: CGPoint(x: 12*s, y: 14*s)
        )
    }

    // MARK: - Share (network nodes)
    private func drawShare(_ path: inout Path, scale s: CGFloat, in rect: CGRect) {
        let r = 2.5 * s
        let top = CGPoint(x: 18*s, y: 5*s)
        let mid = CGPoint(x: 6*s, y: 12*s)
        let bot = CGPoint(x: 18*s, y: 19*s)
        path.addEllipse(in: CGRect(x: top.x-r, y: top.y-r, width: r*2, height: r*2))
        path.addEllipse(in: CGRect(x: mid.x-r, y: mid.y-r, width: r*2, height: r*2))
        path.addEllipse(in: CGRect(x: bot.x-r, y: bot.y-r, width: r*2, height: r*2))
        path.move(to: CGPoint(x: 8.5*s, y: 10.5*s))
        path.addLine(to: CGPoint(x: 15.5*s, y: 6.5*s))
        path.move(to: CGPoint(x: 8.5*s, y: 13.5*s))
        path.addLine(to: CGPoint(x: 15.5*s, y: 17.5*s))
    }

    // MARK: - Check Circle
    private func drawCheckCircle(_ path: inout Path, scale s: CGFloat, in rect: CGRect) {
        let center = CGPoint(x: 12*s, y: 12*s)
        path.addEllipse(in: CGRect(
            x: center.x - 9*s, y: center.y - 9*s,
            width: 18*s, height: 18*s
        ))
        path.move(to: CGPoint(x: 8*s, y: 12*s))
        path.addLine(to: CGPoint(x: 11*s, y: 15*s))
        path.addLine(to: CGPoint(x: 16*s, y: 9*s))
    }

    // MARK: - Alert Triangle
    private func drawAlertTriangle(_ path: inout Path, scale s: CGFloat, in rect: CGRect) {
        path.move(to: CGPoint(x: 12*s, y: 3*s))
        path.addLine(to: CGPoint(x: 22*s, y: 20*s))
        path.addLine(to: CGPoint(x: 2*s, y: 20*s))
        path.closeSubpath()
        path.move(to: CGPoint(x: 12*s, y: 10*s))
        path.addLine(to: CGPoint(x: 12*s, y: 14*s))
        path.move(to: CGPoint(x: 12*s, y: 17*s))
        path.addLine(to: CGPoint(x: 12*s, y: 17.1*s))
    }
}

// MARK: - Convenience modifiers

@available(iOS 15.0, *)
extension DSIcon {
    func weight(_ weight: DSIconWeight) -> DSIcon {
        var copy = self
        copy.weight = weight
        return copy
    }

    func size(_ size: CGFloat) -> DSIcon {
        var copy = self
        copy.size = size
        return copy
    }
}

// MARK: - Icon position for View modifier

enum DSIconPosition {
    case leading, trailing
}

// MARK: - View + dsIcon modifier

@available(iOS 15.0, *)
extension View {
    /// 为任意 View 附加一个 DS 图标
    ///
    /// ```swift
    /// Text("Settings").dsIcon(.settings)
    /// Text("Camera").dsIcon(.camera, weight: .bold, size: 20, color: .dsPrimary, position: .trailing, spacing: 6)
    /// ```
    func dsIcon(
        _ name: DSIconName,
        weight: DSIconWeight = .regular,
        size: CGFloat = 20,
        color: Color? = nil,
        position: DSIconPosition = .leading,
        spacing: CGFloat = DSSpacing.xs
    ) -> some View {
        modifier(DSIconModifier(
            name: name,
            weight: weight,
            size: size,
            color: color,
            position: position,
            spacing: spacing
        ))
    }
}

@available(iOS 15.0, *)
private struct DSIconModifier: ViewModifier {
    let name: DSIconName
    let weight: DSIconWeight
    let size: CGFloat
    let color: Color?
    let position: DSIconPosition
    let spacing: CGFloat

    func body(content: Content) -> some View {
        HStack(spacing: spacing) {
            if position == .leading {
                icon
            }
            content
            if position == .trailing {
                icon
            }
        }
    }

    private var icon: some View {
        DSIcon(name: name, weight: weight, size: size)
            .foregroundColor(color)
    }
}

