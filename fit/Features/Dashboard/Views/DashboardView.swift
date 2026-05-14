import SwiftUI
import SwiftData

@available(iOS 17.0, *)


struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var healthData: HealthKitDayData?
    @State private var isHealthAuthorized = false

    private let healthKitService = HKHealthKitService.shared
    private let healthDataService = DefaultHealthDataService()
    private let userDataService = DefaultUserDataService()

    @Query private var profiles: [UserProfile]
    @Query private var recentAnalyses: [PoseAnalysisRecord]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("你好，\(profile?.name ?? "用户")")
                        .dsTextStyle(.title2)
                        .foregroundColor(.white)

                    Text(greetingText)
                        .dsTextStyle(.caption1)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.lg)

                // Health rings card
                healthCard

                // Today's plan card
                todayPlanCard

                // Recent pose summary
                recentPoseCard
            }
            .padding(.bottom, DSSpacing.huge)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .task {
            await loadHealthData()
        }
    }

    // MARK: - Health Card

    private var healthCard: some View {
        VStack(spacing: DSSpacing.md) {
            HStack {
                Text("今日健康")
                    .dsTextStyle(.body)
                    .foregroundColor(.white)
                Spacer()
                if !isHealthAuthorized {
                    Button("授权") { Task { await requestHealth() } }
                        .dsTextStyle(.caption1)
                        .foregroundColor(.dsPrimary)
                }
            }

            if let data = healthData {
                HStack(spacing: DSSpacing.lg) {
                    healthMetric(icon: "figure.walk", value: "\(data.steps)", unit: "步", color: .dsPrimary)
                    healthMetric(icon: "flame.fill", value: String(format: "%.0f", data.activeEnergyKcal), unit: "kcal", color: .orange)
                    healthMetric(icon: "heart.fill", value: data.heartRateAvg.map { String(format: "%.0f", $0) } ?? "--", unit: "bpm", color: .red)
                    healthMetric(icon: "bed.double.fill", value: data.sleepHours.map { String(format: "%.1f", $0) } ?? "--", unit: "时", color: .purple)
                }
            } else {
                Text(isHealthAuthorized ? "正在加载..." : "授权 HealthKit 获取健康数据")
                    .dsTextStyle(.caption1)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, DSSpacing.md)
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, DSSpacing.lg)
    }

    private func healthMetric(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .dsTextStyle(.body)
                .foregroundColor(.white)
            Text(unit)
                .dsTextStyle(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Plan Card

    private var todayPlanCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("今日计划")
                .dsTextStyle(.body)
                .foregroundColor(.white)

            HStack {
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.title2)
                    .foregroundColor(.dsSuccess)
                Text("暂无训练计划")
                    .dsTextStyle(.caption1)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Recent Pose

    private var recentPoseCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("体态趋势")
                .dsTextStyle(.body)
                .foregroundColor(.white)

            if recentAnalyses.isEmpty {
                Text("完成一次体态分析后，这里会显示你的体态趋势")
                    .dsTextStyle(.caption1)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, DSSpacing.xs)
            } else {
                ForEach(recentAnalyses.prefix(3)) { record in
                    HStack {
                        Text(record.date, style: .date)
                            .dsTextStyle(.caption1)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("评分: \(record.overallScore)")
                            .dsTextStyle(.caption1)
                            .foregroundColor(scoreColor(record.overallScore))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Helpers

    private var profile: UserProfile? {
        profiles.first
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "早上好！今天是个训练的好日子"
        case 12..<18: return "下午好！别忘了活动一下"
        case 18..<22: return "晚上好！今天运动了吗？"
        default: return "夜深了，早点休息"
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return .dsSuccess
        case 60...: return .yellow
        default: return .orange
        }
    }

    private func loadHealthData() async {
        do {
            isHealthAuthorized = try await healthKitService.requestAuthorization()
            if isHealthAuthorized {
                let data = try await healthKitService.fetchDailyData(for: Date())
                healthData = data
                let dailyHealth = DailyHealthData(date: data.date)
                dailyHealth.steps = data.steps
                dailyHealth.activeEnergyKcal = data.activeEnergyKcal
                dailyHealth.heartRateAvg = data.heartRateAvg
                dailyHealth.restingHeartRate = data.restingHeartRate
                dailyHealth.sleepHours = data.sleepHours
                try healthDataService.saveDailyHealth(dailyHealth, context: modelContext)
            }
        } catch {
            // HealthKit unavailable or denied — show empty state
        }
    }

    private func requestHealth() async {
        isHealthAuthorized = (try? await healthKitService.requestAuthorization()) ?? false
        if isHealthAuthorized { await loadHealthData() }
    }
}
