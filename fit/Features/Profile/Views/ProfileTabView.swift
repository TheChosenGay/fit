import SwiftUI
import SwiftData

@available(iOS 17.0, *)


struct ProfileTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showEdit = false
    @State private var showSettings = false
    @State private var appear = false

    private let userDataService = DefaultUserDataService()

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                // Hero
                heroSection
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)

                // Body stats
                bodyStatsCard
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)

                // Goal + activity
                if let profile {
                    goalActivityCard(profile)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)
                }

                // Menu
                menuSection
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)

                // App version
                Text("Fit v1.0.0")
                    .dsTextStyle(.caption2)
                    .foregroundColor(.dsLabelTertiary)
                    .padding(.top, DSSpacing.xs)
            }
            .padding(.bottom, DSSpacing.huge)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .sheet(isPresented: $showEdit) {
            ProfileEditView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
    }

    private var profile: UserProfile? { profiles.first }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: DSSpacing.sm) {
            // Gradient badge ring
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.dsPrimary, .dsSecondary, .dsPrimaryVariant],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 84, height: 84)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.dsPrimary.opacity(0.2), .dsSecondary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)

                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }

            Text(profile?.name ?? "未设置档案")
                .dsTextStyle(.title2)
                .foregroundColor(.dsLabel)

            if let goal = profile?.fitnessGoal {
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: goalIcon(goal))
                    Text(goalLabel(goal))
                }
                .dsTextStyle(.caption1)
                .foregroundColor(.dsPrimary)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xxs)
                .background(
                    Capsule()
                        .fill(Color.dsPrimary.opacity(0.12))
                )
            }

            if let profile {
                Text("已陪伴 \(daysSince(profile.createdAt)) 天")
                    .dsTextStyle(.caption2)
                    .foregroundColor(.dsLabelTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.xl)
        .padding(.bottom, DSSpacing.sm)
    }

    // MARK: - Body Stats

    private var bodyStatsCard: some View {
        HStack(spacing: 0) {
            statItem(
                value: profile?.heightCm.map { "\(Int($0))" } ?? "--",
                unit: "cm",
                label: "身高",
                icon: "ruler.fill",
                color: .dsPrimary
            )
            Rectangle()
                .fill(Color.dsSeparator)
                .frame(width: 1, height: 40)
            statItem(
                value: profile?.weightKg.map { String(format: "%.1f", $0) } ?? "--",
                unit: "kg",
                label: "体重",
                icon: "scalemass.fill",
                color: .dsSecondary
            )
            Rectangle()
                .fill(Color.dsSeparator)
                .frame(width: 1, height: 40)
            statItem(
                value: profile?.dateOfBirth.map { "\(age(from: $0))" } ?? "--",
                unit: "岁",
                label: "年龄",
                icon: "calendar",
                color: .dsWarning
            )
            Rectangle()
                .fill(Color.dsSeparator)
                .frame(width: 1, height: 40)
            statItem(
                value: bmi,
                unit: "",
                label: "BMI",
                icon: "heart.fill",
                color: .dsSuccess
            )
        }
        .padding(.vertical, DSSpacing.md)
        .padding(.horizontal, DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsSurfaceSecondary)
        )
        .dsShadow(.subtle)
        .padding(.horizontal, DSSpacing.lg)
    }

    private func statItem(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(.dsLabel)
                if !unit.isEmpty {
                    Text(unit)
                        .dsTextStyle(.caption2)
                        .foregroundColor(.dsLabelTertiary)
                }
            }
            Text(label)
                .dsTextStyle(.caption2)
                .foregroundColor(.dsLabelTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Goal & Activity Card

    private func goalActivityCard(_ profile: UserProfile) -> some View {
        HStack(spacing: DSSpacing.lg) {
            // Goal
            VStack(alignment: .leading, spacing: 4) {
                Text("健身目标")
                    .dsTextStyle(.caption2)
                    .foregroundColor(.dsLabelTertiary)
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: goalIcon(profile.fitnessGoal ?? ""))
                        .foregroundColor(.dsPrimary)
                    Text(goalLabel(profile.fitnessGoal ?? ""))
                        .dsTextStyle(.callout)
                        .foregroundColor(.dsLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.dsSeparator)
                .frame(width: 1, height: 32)

            // Activity
            VStack(alignment: .leading, spacing: 4) {
                Text("活动水平")
                    .dsTextStyle(.caption2)
                    .foregroundColor(.dsLabelTertiary)
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.dsSecondary)
                    Text(activityLabel(profile.activityLevel ?? ""))
                        .dsTextStyle(.callout)
                        .foregroundColor(.dsLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsSurfaceSecondary)
        )
        .dsShadow(.subtle)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Menu

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuItem(icon: "person.text.rectangle.fill", title: "编辑档案", color: .dsPrimary) {
                showEdit = true
            }
            menuDivider
            menuItem(icon: "heart.text.square.fill", title: "健康状况", color: .dsError) {
                // navigate to HealthConditionsView
            }
            menuDivider
            menuItem(icon: "chart.line.uptrend.xyaxis", title: "体重历史", color: .dsSecondary) {}
            menuDivider
            menuItem(icon: "gearshape.fill", title: "设置", color: .gray) {
                showSettings = true
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsSurfaceSecondary)
        )
        .dsShadow(.subtle)
        .padding(.horizontal, DSSpacing.lg)
    }

    private var menuDivider: some View {
        Divider()
            .background(Color.dsSeparator)
            .padding(.leading, DSSpacing.xxxl)
    }

    private func menuItem(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.15))
                    )

                Text(title)
                    .dsTextStyle(.body)
                    .foregroundColor(.dsLabel)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.dsLabelTertiary)
            }
            .padding(DSSpacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var bmi: String {
        guard let h = profile?.heightCm, let w = profile?.weightKg, h > 0 else { return "--" }
        let bmi = w / ((h / 100) * (h / 100))
        return String(format: "%.1f", bmi)
    }

    private func age(from date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }

    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
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

    private func goalIcon(_ goal: String) -> String {
        switch goal {
        case "posture_correction": return "figure.mind.and.body"
        case "weight_loss": return "flame.fill"
        case "muscle_gain": return "figure.strengthtraining.traditional"
        case "general_fitness": return "heart.fill"
        default: return "heart.fill"
        }
    }

    private func activityLabel(_ level: String) -> String {
        switch level {
        case "sedentary": return "久坐不动"
        case "light": return "轻度活动"
        case "moderate": return "中等活动"
        case "active": return "活跃"
        case "very_active": return "非常活跃"
        default: return level
        }
    }
}
