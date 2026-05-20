import SwiftUI

@available(iOS 17.0, *)


struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useDarkMode") private var useDarkMode = true
    @State private var notificationsEnabled = true
    @State private var voiceEnabled = true
    @State private var hapticEnabled = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    // Appearance
                    settingsCard("外观") {
                        ToggleRow(
                            icon: "moon.stars.fill",
                            label: "深色模式",
                            color: .indigo,
                            isOn: $useDarkMode
                        )
                    }

                    // Coaching
                    settingsCard("AI 教练") {
                        ToggleRow(
                            icon: "waveform",
                            label: "语音播报",
                            color: .dsPrimary,
                            isOn: $voiceEnabled
                        )
                        settingsDivider
                        ToggleRow(
                            icon: "iphone.radiowaves.left.and.right",
                            label: "触觉反馈",
                            color: .orange,
                            isOn: $hapticEnabled
                        )
                    }

                    // Notifications
                    settingsCard("通知") {
                        ToggleRow(
                            icon: "bell.badge.fill",
                            label: "训练提醒",
                            color: .red,
                            isOn: $notificationsEnabled
                        )
                    }

                    // Privacy
                    settingsCard("隐私") {
                        NavigationLink {
                            privacyDetail
                        } label: {
                            InfoRow(icon: "hand.raised.fill", label: "隐私政策", color: .gray)
                        }
                        .buttonStyle(.plain)

                        settingsDivider

                        NavigationLink {
                            termsDetail
                        } label: {
                            InfoRow(icon: "doc.text.fill", label: "用户协议", color: .gray)
                        }
                        .buttonStyle(.plain)

                        settingsDivider

                        InfoRow(icon: "checkmark.shield.fill", label: "数据存储在本机", color: .dsSuccess)
                    }

                    // About
                    settingsCard("关于") {
                        InfoRow(icon: "apps.iphone", label: "版本", value: "1.0.0", color: .blue)
                        settingsDivider
                        InfoRow(icon: "cpu.fill", label: "AI 模型", value: "DeepSeek", color: .purple)
                        settingsDivider
                        InfoRow(icon: "heart.circle.fill", label: "Made with love", value: "", color: .pink)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.xxxl)
            }
            .background(Color.dsBackground.ignoresSafeArea())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundColor(.dsPrimary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(title)
                .dsTextStyle(.headline)
                .foregroundColor(.dsLabel)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                    .fill(Color.dsSurfaceSecondary)
            )
            .dsShadow(.subtle)
        }
    }

    private var settingsDivider: some View {
        Divider()
            .background(Color.dsSeparator)
            .padding(.leading, DSSpacing.xxxl)
    }

    // MARK: - Privacy / Terms

    private var privacyDetail: some View {
        ScrollView {
            Text("""
            Fit 重视你的隐私。

            所有健康数据存储在本机，通过 Apple HealthKit 读取。
            姿态分析照片和视频仅在本机处理。
            AI 对话通过加密网络传输，不保存到服务器。

            我们不会收集、出售或分享你的个人数据。
            """)
            .dsTextStyle(.body)
            .foregroundColor(.dsLabelSecondary)
            .padding(DSSpacing.lg)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var termsDetail: some View {
        ScrollView {
            Text("""
            使用 Fit 即表示你同意以下条款：

            1. Fit 提供健身建议供参考，不构成医疗建议。开始任何训练前请咨询医生。
            2. AI 教练建议基于算法生成，可能存在误差。
            3. 用户对自己的人身安全负责。
            4. 本协议可能随时更新。
            """)
            .dsTextStyle(.body)
            .foregroundColor(.dsLabelSecondary)
            .padding(DSSpacing.lg)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .navigationTitle("用户协议")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable rows

private struct ToggleRow: View {
    let icon: String
    let label: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                )
            Text(label)
                .dsTextStyle(.body)
                .foregroundColor(.dsLabel)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(.dsPrimary)
                .labelsHidden()
        }
        .padding(DSSpacing.md)
    }
}

private struct InfoRow: View {
    let icon: String
    let label: String
    var value: String = ""
    let color: Color

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                )
            Text(label)
                .dsTextStyle(.body)
                .foregroundColor(.dsLabel)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .dsTextStyle(.caption1)
                    .foregroundColor(.dsLabelTertiary)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.dsLabelTertiary)
        }
        .padding(DSSpacing.md)
    }
}
