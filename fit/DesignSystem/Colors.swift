import SwiftUI
import UIKit

// MARK: - Design System Colors

@available(iOS 15.0, *)
extension Color {
    /// 主色，品牌核心
    static let dsPrimary = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "4D9AFF") : UIColor(hex: "0A6CFF") })

    /// 主色变体，用于强调
    static let dsPrimaryVariant = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "6DB3FF") : UIColor(hex: "0052CC") })

    /// 辅助色，科技青
    static let dsSecondary = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "18DDEB") : UIColor(hex: "00B8D4") })

    /// 辅助色变体
    static let dsSecondaryVariant = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "4DE8F4") : UIColor(hex: "0097A7") })

    /// 页面背景
    static let dsBackground = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "0A0E1A") : UIColor(hex: "FFFFFF") })

    /// 分组背景
    static let dsBackgroundSecondary = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "111827") : UIColor(hex: "F2F4F8") })

    /// 卡片表面
    static let dsSurface = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "1A2135") : UIColor(hex: "FFFFFF") })

    /// 次级表面
    static let dsSurfaceSecondary = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "232B3E") : UIColor(hex: "F7F8FB") })

    /// 主文字
    static let dsLabel = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "F1F5F9") : UIColor(hex: "111827") })

    /// 次要文字
    static let dsLabelSecondary = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "94A3B8") : UIColor(hex: "4B5563") })

    /// 第三级文字
    static let dsLabelTertiary = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "64748B") : UIColor(hex: "9CA3AF") })

    /// 分隔线
    static let dsSeparator = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "2D3748") : UIColor(hex: "E2E8F0") })

    /// 填充色
    static let dsFill = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "4D9AFF") : UIColor(hex: "0A6CFF") })

    /// 错误
    static let dsError = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "F87171") : UIColor(hex: "DC2626") })

    /// 成功
    static let dsSuccess = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "34D399") : UIColor(hex: "059669") })

    /// 警告
    static let dsWarning = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(hex: "FBBF24") : UIColor(hex: "D97706") })
}

// MARK: - UIColor Hex Init

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}
