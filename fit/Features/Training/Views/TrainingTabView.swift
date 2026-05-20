import SwiftUI
import SwiftData

@available(iOS 17.0, *)


struct TrainingTabView: View {
    @State private var showCamera = false
    @State private var showCoach = false
    @Query(filter: #Predicate<TrainingPlan> { $0.isActive }, sort: \TrainingPlan.createdAt, order: .reverse) private var activePlans: [TrainingPlan]

    private var activePlan: TrainingPlan? { activePlans.first }

    private var todaySession: PlannedSession? {
        guard let plan = activePlan else { return nil }
        let today = Calendar.current.component(.weekday, from: Date())
        let adjusted = today == 1 ? 7 : today - 1
        return plan.sessions?.first { $0.dayOfWeek == adjusted }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Section: 体态检测
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("体态检测")
                        .dsTextStyle(.headline)
                        .foregroundColor(.dsLabel)
                        .padding(.horizontal, DSSpacing.lg)

                    // 实时摄像头
                    entryCard(
                        icon: "video.fill",
                        iconColor: .dsSuccess,
                        bgColor: Color.dsSuccess.opacity(0.15),
                        title: "实时摄像头检测",
                        subtitle: "打开摄像头，实时检测并录制骨骼姿态",
                        action: { showCamera = true }
                    )
                    .padding(.horizontal, DSSpacing.lg)

                    // 从视频分析
                    NavigationLink {
                        VideoAnalysisView()
                    } label: {
                        entryCardContent(
                            icon: "film.fill",
                            iconColor: .dsPrimary,
                            bgColor: Color.dsPrimary.opacity(0.15),
                            title: "从视频分析",
                            subtitle: "选择已有视频，逐帧检测骨骼并生成分析结果"
                        )
                    }
                    .padding(.horizontal, DSSpacing.lg)

                    // 拍照分析
                    NavigationLink {
                        CameraView()
                    } label: {
                        entryCardContent(
                            icon: "camera.fill",
                            iconColor: .dsPrimary,
                            bgColor: Color.dsPrimary.opacity(0.15),
                            title: "拍照体态分析",
                            subtitle: "拍摄照片，AI 分析体态并给出矫正建议"
                        )
                    }
                    .padding(.horizontal, DSSpacing.lg)
                }
                .fullScreenCover(isPresented: $showCamera) {
                    RealTimeCameraView()
                }

                // Section: 实时训练
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("实时训练")
                        .dsTextStyle(.headline)
                        .foregroundColor(.dsLabel)
                        .padding(.horizontal, DSSpacing.lg)

                    entryCard(
                        icon: "figure.strengthtraining.traditional",
                        iconColor: .dsError,
                        bgColor: Color.dsError.opacity(0.15),
                        title: "AI 教练指导训练",
                        subtitle: "实时摄像头追踪动作，AI 语音指导纠正",
                        action: { showCoach = true }
                    )
                    .padding(.horizontal, DSSpacing.lg)

                    NavigationLink {
                        StandardSequenceListView()
                    } label: {
                        entryCardContent(
                            icon: "figure.run.square.stack",
                            iconColor: .blue,
                            bgColor: Color.blue.opacity(0.15),
                            title: "标准动作库",
                            subtitle: "管理标准动作，教学演示或实时对比训练"
                        )
                    }
                    .padding(.horizontal, DSSpacing.lg)
                }
                .fullScreenCover(isPresented: $showCoach) {
                    RealtimeCoachView(exercise: .squat)
                }

                // Section: 训练计划
                if let plan = activePlan {
                    TrainingPlanCardView(plan: plan, todaySession: todaySession)
                } else {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("训练计划")
                            .dsTextStyle(.headline)
                            .foregroundColor(.dsLabel)
                            .padding(.horizontal, DSSpacing.lg)

                        NavigationLink {
                            TrainingPlanGenerationView()
                        } label: {
                            entryCardContent(
                                icon: "list.clipboard",
                                iconColor: .dsSecondary,
                                bgColor: Color.dsSecondary.opacity(0.15),
                                title: "创建训练计划",
                                subtitle: "AI 根据你的目标生成个性化周训练计划"
                            )
                        }
                        .padding(.horizontal, DSSpacing.lg)
                    }
                }

                // Section: 检测历史
                AnalysisHistorySection()
            }
            .padding(.bottom, DSSpacing.huge)
        }
        .background(Color.dsBackground.ignoresSafeArea())
    }

    // MARK: - Entry card helpers

    private func entryCard(
        icon: String,
        iconColor: Color,
        bgColor: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            entryCardContent(icon: icon, iconColor: iconColor, bgColor: bgColor, title: title, subtitle: subtitle)
        }
    }

    private func entryCardContent(
        icon: String,
        iconColor: Color,
        bgColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(iconColor)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .fill(iconColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .dsTextStyle(.callout)
                    .foregroundColor(.dsLabel)
                Text(subtitle)
                    .dsTextStyle(.caption2)
                    .foregroundColor(.dsLabelTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.dsLabelTertiary)
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsSurfaceSecondary)
        )
        .dsShadow(.subtle)
    }
}

// MARK: - Analysis History Section

@available(iOS 17.0, *)
struct AnalysisHistorySection: View {
    @Query(sort: \PoseAnalysisRecord.date, order: .reverse) private var records: [PoseAnalysisRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("检测历史")
                .dsTextStyle(.headline)
                .foregroundColor(.dsLabel)
                .padding(.horizontal, DSSpacing.lg)

            if records.isEmpty {
                Text("暂无检测记录")
                    .dsTextStyle(.caption1)
                    .foregroundColor(.dsLabelTertiary)
                    .padding(DSSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                            .fill(Color.dsSurfaceSecondary)
                    )
                    .padding(.horizontal, DSSpacing.lg)
            } else {
                ForEach(records) { record in
                    NavigationLink {
                        AnalysisHistoryDetailView(record: record)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.date, style: .date)
                                    .dsTextStyle(.caption1)
                                    .foregroundColor(.dsLabel)
                                Text(record.summary)
                                    .dsTextStyle(.caption2)
                                    .foregroundColor(.dsLabelTertiary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Text("\(record.overallScore)")
                                    .dsTextStyle(.callout)
                                    .foregroundColor(scoreColor(record.overallScore))
                                Text("分")
                                    .dsTextStyle(.caption2)
                                    .foregroundColor(.dsLabelTertiary)
                            }
                        }
                        .padding(DSSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                                .fill(Color.dsSurfaceSecondary)
                        )
                        .dsShadow(.subtle)
                    }
                    .padding(.horizontal, DSSpacing.lg)
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return .dsSuccess
        case 60...: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Analysis History Detail View

@available(iOS 17.0, *)
struct AnalysisHistoryDetailView: View {
    let record: PoseAnalysisRecord

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Score
                VStack(spacing: 8) {
                    Text("\(record.overallScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(scoreColor(record.overallScore))
                    Text("综合评分")
                        .dsTextStyle(.caption1)
                        .foregroundColor(.dsLabelTertiary)
                }
                .padding(DSSpacing.lg)

                // Angles
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("体态数据")
                        .dsTextStyle(.headline)
                        .foregroundColor(.dsLabel)

                    if let hf = record.headForward {
                        angleRow("头部前伸", value: String(format: "%.1f°", hf))
                    }
                    if let sd = record.shoulderDiff {
                        angleRow("肩部高度差", value: String(format: "%.1f px", sd))
                    }
                    if let rs = record.roundShoulder {
                        angleRow("圆肩角度", value: String(format: "%.1f°", rs))
                    }
                    if let pt = record.pelvicTilt {
                        angleRow("骨盆倾斜", value: String(format: "%.1f°", pt))
                    }
                    if let la = record.legAlignment {
                        angleRow("腿部对齐", value: String(format: "%.1f°", la))
                    }
                }
                .padding(DSSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .fill(Color.dsSurfaceSecondary)
                )
                .dsShadow(.subtle)
                .padding(.horizontal, DSSpacing.lg)

                // Summary
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("AI 总结")
                        .dsTextStyle(.headline)
                        .foregroundColor(.dsLabel)
                    Text(record.summary)
                        .dsTextStyle(.caption1)
                        .foregroundColor(.dsLabelSecondary)
                }
                .padding(DSSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .fill(Color.dsSurfaceSecondary)
                )
                .dsShadow(.subtle)
                .padding(.horizontal, DSSpacing.lg)

                // Issues
                if let issues = record.issues, !issues.isEmpty {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("体态问题")
                            .dsTextStyle(.body)
                            .foregroundColor(.dsLabel)

                        ForEach(Array(issues)) { issue in
                            HStack {
                                Image(systemName: severityIcon(issue.severity))
                                    .foregroundColor(severityColor(issue.severity))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.name)
                                        .dsTextStyle(.caption1)
                                        .foregroundColor(.dsLabel)
                                    Text(issue.issueDescription)
                                        .dsTextStyle(.caption2)
                                        .foregroundColor(.dsLabelTertiary)
                                }
                            }
                            .padding(DSSpacing.xs)
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
            }
            .padding(.bottom, DSSpacing.huge)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .navigationTitle("分析详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func angleRow(_ name: String, value: String) -> some View {
        HStack {
            Text(name)
                .dsTextStyle(.caption1)
                .foregroundColor(.dsLabelSecondary)
            Spacer()
            Text(value)
                .dsTextStyle(.caption1)
                .foregroundColor(.dsLabel)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return .dsSuccess
        case 60...: return .yellow
        default: return .orange
        }
    }

    private func severityIcon(_ severity: String) -> String {
        switch severity {
        case "severe": return "exclamationmark.triangle.fill"
        case "moderate": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "severe": return .red
        case "moderate": return .orange
        default: return .yellow
        }
    }
}
