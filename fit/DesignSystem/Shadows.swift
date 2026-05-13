import SwiftUI

// MARK: - Design System Shadows

@available(iOS 15.0, *)
struct DSShadow: ViewModifier {
    enum Level {
        case subtle, medium, prominent
    }

    let level: Level
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        switch level {
        case .subtle:
            content.shadow(
                color: shadowColor.opacity(colorScheme == .dark ? 0.20 : 0.06),
                radius: 3, x: 0, y: 1
            )
        case .medium:
            content.shadow(
                color: shadowColor.opacity(colorScheme == .dark ? 0.30 : 0.10),
                radius: 8, x: 0, y: 2
            )
        case .prominent:
            content.shadow(
                color: shadowColor.opacity(colorScheme == .dark ? 0.40 : 0.16),
                radius: 16, x: 0, y: 4
            )
        }
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black : Color(red: 15/255, green: 23/255, blue: 42/255)
    }
}

@available(iOS 15.0, *)
extension View {
    func dsShadow(_ level: DSShadow.Level) -> some View {
        modifier(DSShadow(level: level))
    }
}
