import SwiftUI
import SwiftData

@available(iOS 17.0, *)


struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var healthData: HealthKitDayData?
    @State private var isHealthAuthorized = false
    @State private var appear = false

    private let healthKitService = HKHealthKitService.shared
    private let healthDataService = DefaultHealthDataService()
    private let userDataService = DefaultUserDataService()

    @Query private var profiles: [UserProfile]
    @Query private var recentAnalyses: [PoseAnalysisRecord]

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                // Gradient header
                headerSection
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 16)

                // Health rings card
                healthCard
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)

                // Today's plan
                todayPlanCard
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)

                // Recent pose
                recentPoseCard
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)
            }
            .padding(.bottom, DSSpacing.huge)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .task {
            await loadHealthData()
            await backfillRecentWeek()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) {
                appear = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("你好，\(profile?.name ?? "用户")")
                        .dsTextStyle(.title2)
                        .foregroundColor(.dsLabel)

                    Text(greetingText)
                        .dsTextStyle(.caption1)
                        .foregroundColor(.dsLabelSecondary)
                }

                Spacer()

                // Date badge
                Text(todayString)
                    .dsTextStyle(.caption1)
                    .foregroundColor(.dsLabelSecondary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color.dsSurfaceSecondary)
                    )
            }

        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.lg)
    }

    // MARK: - Health Card

    private var healthCard: some View {
        VStack(spacing: DSSpacing.md) {
            HStack {
                Text("今日健康")
                    .dsTextStyle(.headline)
                    .foregroundColor(.dsLabel)
                Spacer()
                if !isHealthAuthorized {
                    Button("授权") { Task { await requestHealth() } }
                        .dsTextStyle(.caption1)
                        .foregroundColor(.dsPrimary)
                }
            }

            if let data = healthData {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.sm), count: 5), spacing: DSSpacing.md) {
                    healthMetric(icon: "figure.walk", value: "\(data.steps)", unit: "步", color: .dsPrimary)
                    healthMetric(icon: "flame.fill", value: String(format: "%.0f", data.activeEnergyKcal), unit: "kcal", color: .orange)
                    healthMetric(icon: "heart.fill", value: data.heartRateAvg.map { String(format: "%.0f", $0) } ?? "--", unit: "bpm", color: .red)
                    healthMetric(icon: "bed.double.fill", value: data.sleepHours.map { String(format: "%.1f", $0) } ?? "--", unit: "时", color: .purple)
                    healthMetric(icon: "ruler.fill", value: data.distanceWalkedKm.map { String(format: "%.1f", $0) } ?? "--", unit: "km", color: .green)
                }

                Divider().background(Color.dsSeparator)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.sm), count: 5), spacing: DSSpacing.md) {
                    healthMetric(icon: "figure.run", value: "\(data.exerciseMinutes)", unit: "练分", color: .cyan)
                    healthMetric(icon: "figure.stand", value: "\(data.standMinutes)", unit: "站分", color: .blue)
                    healthMetric(icon: "waveform.path.ecg", value: data.heartRateVariability.map { String(format: "%.0f", $0) } ?? "--", unit: "HRV", color: .pink)
                    healthMetric(icon: "lungs.fill", value: data.respiratoryRateAvg.map { String(format: "%.0f", $0) } ?? "--", unit: "次/分", color: .teal)
                    healthMetric(icon: "drop.fill", value: data.bloodOxygenAvg.map { String(format: "%.0f", $0) } ?? "--", unit: "%", color: .mint)
                }
            } else {
                emptyState(
                    icon: "heart.text.square",
                    message: isHealthAuthorized ? "正在加载健康数据..." : "授权 HealthKit 获取健康数据"
                )
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsSurfaceSecondary)
        )
        .dsShadow(.subtle)
        .padding(.horizontal, DSSpacing.lg)
    }

    private func healthMetric(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                )

            Text(value)
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.dsLabel)

            Text(unit)
                .dsTextStyle(.caption2)
                .foregroundColor(.dsLabelTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Plan Card

    private var todayPlanCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("今日计划")
                .dsTextStyle(.headline)
                .foregroundColor(.dsLabel)

            HStack {
                ZStack {
                    Circle()
                        .fill(Color.dsWarning.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.strengthtraining.functional")
                        .font(.title3)
                        .foregroundColor(.dsWarning)
                }
                Spacer().frame(width: DSSpacing.sm)
                VStack(alignment: .leading, spacing: 4) {
                    Text("暂无训练计划")
                        .dsTextStyle(.callout)
                        .foregroundColor(.dsLabel)
                    Text("创建计划让 AI 教练安排训练")
                        .dsTextStyle(.caption2)
                        .foregroundColor(.dsLabelTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.dsLabelTertiary)
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsSurfaceSecondary)
        )
        .dsShadow(.subtle)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Recent Pose

    private var recentPoseCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("体态趋势")
                .dsTextStyle(.headline)
                .foregroundColor(.dsLabel)

            if recentAnalyses.isEmpty {
                emptyState(
                    icon: "person.and.background.dotted",
                    message: "完成一次体态分析后，这里会显示趋势"
                )
            } else {
                ForEach(Array(recentAnalyses.prefix(3))) { record in
                    HStack(spacing: DSSpacing.sm) {
                        // Score ring
                        ZStack {
                            Circle()
                                .stroke(scoreColor(record.overallScore).opacity(0.3), lineWidth: 3)
                                .frame(width: 36, height: 36)
                            Circle()
                                .trim(from: 0, to: Double(record.overallScore) / 100)
                                .stroke(
                                    scoreColor(record.overallScore),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 36, height: 36)
                                .rotationEffect(.degrees(-90))
                            Text("\(record.overallScore)")
                                .font(.system(.caption2, design: .rounded).bold())
                                .foregroundColor(scoreColor(record.overallScore))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.date, style: .date)
                                .dsTextStyle(.caption1)
                                .foregroundColor(.dsLabel)
                            Text(record.summary)
                                .dsTextStyle(.caption2)
                                .foregroundColor(.dsLabelTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.dsLabelTertiary)
                    }
                    .padding(.vertical, DSSpacing.xxs)
                }
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsSurfaceSecondary)
        )
        .dsShadow(.subtle)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Shared

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: DSSpacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.dsLabelTertiary.opacity(0.5))
            Text(message)
                .dsTextStyle(.caption1)
                .foregroundColor(.dsLabelTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.lg)
    }

    // MARK: - Data

    private func backfillRecentWeek() async {
        guard isHealthAuthorized else { return }
        let endDate = Calendar.current.startOfDay(for: Date())
        guard let startDate = Calendar.current.date(byAdding: .day, value: -6, to: endDate) else { return }

        do {
            let existing = try healthDataService.fetchHealthRange(from: startDate, to: endDate, context: modelContext)
            let existingDates = Set(existing.map(\.date))

            let allData = try await healthKitService.fetchDataRange(from: startDate, to: endDate)
            for data in allData where !existingDates.contains(data.date) {
                try healthDataService.saveHealthData(data, context: modelContext)
            }
        } catch {
            // Silently skip
        }
    }

    // MARK: - Helpers

    private var profile: UserProfile? { profiles.first }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: Date())
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
        case 60...: return .dsWarning
        default: return .dsError
        }
    }

    private func loadHealthData() async {
        do {
            isHealthAuthorized = try await healthKitService.requestAuthorization()
            if isHealthAuthorized {
                let data = try await healthKitService.fetchDailyData(for: Date())
                healthData = data
                try healthDataService.saveHealthData(data, context: modelContext)
            }
        } catch {
            // HealthKit unavailable or denied
        }
    }

    private func requestHealth() async {
        isHealthAuthorized = (try? await healthKitService.requestAuthorization()) ?? false
        if isHealthAuthorized { await loadHealthData() }
    }
}
