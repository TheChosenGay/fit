import SwiftUI
import SwiftData

@available(iOS 17.0, *)


struct ProfileTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showEdit = false

    private let userDataService = DefaultUserDataService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Avatar + Name
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.dsPrimary)

                    Text(profile?.name ?? "未设置")
                        .dsTextStyle(.title2)
                        .foregroundColor(.white)

                    if let goal = profile?.fitnessGoal {
                        Text(goalLabel(goal))
                            .dsTextStyle(.caption1)
                            .foregroundColor(.dsPrimary)
                            .padding(.horizontal, DSSpacing.sm)
                            .padding(.vertical, DSSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: DSCornerRadius.capsule)
                                    .fill(Color.dsPrimary.opacity(0.15))
                            )
                    }
                }
                .padding(.top, DSSpacing.lg)

                // Body info
                if let profile {
                    infoCard {
                        HStack(spacing: DSSpacing.lg) {
                            bodyInfoItem("身高", value: profile.heightCm.map { "\(Int($0)) cm" } ?? "--")
                            bodyInfoItem("体重", value: profile.weightKg.map { "\(String(format: "%.1f", $0)) kg" } ?? "--")
                            bodyInfoItem("年龄", value: profile.dateOfBirth.map { "\(age(from: $0))" } ?? "--")
                        }
                    }
                }

                // Health conditions
                if let conditions = profile?.healthConditions, !conditions.isEmpty {
                    infoCard {
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Text("健康状况")
                                .dsTextStyle(.caption1)
                                .foregroundColor(.white)
                            ForEach(Array(conditions)) { condition in
                                HStack {
                                    Image(systemName: condition.isActive ? "stethoscope" : "checkmark.circle")
                                        .foregroundColor(condition.isActive ? .orange : .dsSuccess)
                                    Text(condition.name)
                                        .dsTextStyle(.caption1)
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    if let severity = condition.severity {
                                        Text(severityLabel(severity))
                                            .dsTextStyle(.caption2)
                                            .foregroundColor(severityColor(severity))
                                    }
                                }
                            }
                        }
                    }
                }

                // Menu
                VStack(spacing: 0) {
                    menuRow(icon: "person.fill", title: "编辑档案") { showEdit = true }
                    Divider().background(Color.white.opacity(0.1))
                    NavigationLink {
                        HealthConditionsView()
                    } label: {
                        menuRowContent(icon: "heart.text.square.fill", title: "健康状况")
                    }
                    Divider().background(Color.white.opacity(0.1))
                    menuRow(icon: "scalemass.fill", title: "体重历史")
                    Divider().background(Color.white.opacity(0.1))
                    menuRow(icon: "gearshape.fill", title: "设置")
                }
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .fill(Color.white.opacity(0.08))
                )
                .padding(.horizontal, DSSpacing.lg)
            }
            .padding(.bottom, DSSpacing.huge)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .sheet(isPresented: $showEdit) {
            ProfileEditView()
        }
    }

    private var profile: UserProfile? { profiles.first }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(DSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                    .fill(Color.white.opacity(0.08))
            )
            .padding(.horizontal, DSSpacing.lg)
    }

    private func bodyInfoItem(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .dsTextStyle(.body)
                .foregroundColor(.white)
            Text(label)
                .dsTextStyle(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func menuRow(icon: String, title: String, action: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            menuRowContent(icon: icon, title: title)
        }
    }

    private func menuRowContent(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.dsPrimary)
                .frame(width: 24)
            Text(title)
                .dsTextStyle(.body)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(DSSpacing.md)
    }

    private func goalLabel(_ goal: String) -> String {
        switch goal {
        case "posture_correction": return "体态矫正"
        case "weight_loss": return "减脂"
        case "muscle_gain": return "增肌"
        case "general_fitness": return "综合健康"
        default: return goal
        }
    }

    private func severityLabel(_ severity: String) -> String {
        switch severity {
        case "mild": return "轻度"
        case "moderate": return "中度"
        case "severe": return "重度"
        default: return severity
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "mild": return .yellow
        case "moderate": return .orange
        case "severe": return .red
        default: return .gray
        }
    }

    private func age(from date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }
}
