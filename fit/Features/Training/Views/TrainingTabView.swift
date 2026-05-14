import SwiftUI
import SwiftData

@available(iOS 17.0, *)


struct TrainingTabView: View {
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Section: 体态检测
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("体态检测")
                        .dsTextStyle(.body)
                        .foregroundColor(.white)
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
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(iconColor)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .fill(bgColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .dsTextStyle(.body)
                    .foregroundColor(.white)
                Text(subtitle)
                    .dsTextStyle(.caption1)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Analysis History Section

@available(iOS 17.0, *)
struct AnalysisHistorySection: View {
    @Query(sort: \PoseAnalysisRecord.date, order: .reverse) private var records: [PoseAnalysisRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("检测历史")
                .dsTextStyle(.body)
                .foregroundColor(.white)
                .padding(.horizontal, DSSpacing.lg)

            if records.isEmpty {
                Text("暂无检测记录")
                    .dsTextStyle(.caption1)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(DSSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                            .fill(Color.white.opacity(0.08))
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
                                    .foregroundColor(.white)
                                Text(record.summary)
                                    .dsTextStyle(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Text("\(record.overallScore)")
                                    .dsTextStyle(.body)
                                    .foregroundColor(scoreColor(record.overallScore))
                                Text("分")
                                    .dsTextStyle(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(DSSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                                .fill(Color.white.opacity(0.08))
                        )
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
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(DSSpacing.lg)

                // Angles
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("体态数据")
                        .dsTextStyle(.body)
                        .foregroundColor(.white)

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
                        .fill(Color.white.opacity(0.08))
                )
                .padding(.horizontal, DSSpacing.lg)

                // Summary
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("AI 总结")
                        .dsTextStyle(.body)
                        .foregroundColor(.white)
                    Text(record.summary)
                        .dsTextStyle(.caption1)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(DSSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .fill(Color.white.opacity(0.08))
                )
                .padding(.horizontal, DSSpacing.lg)

                // Issues
                if let issues = record.issues, !issues.isEmpty {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("体态问题")
                            .dsTextStyle(.body)
                            .foregroundColor(.white)

                        ForEach(Array(issues)) { issue in
                            HStack {
                                Image(systemName: severityIcon(issue.severity))
                                    .foregroundColor(severityColor(issue.severity))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.name)
                                        .dsTextStyle(.caption1)
                                        .foregroundColor(.white)
                                    Text(issue.issueDescription)
                                        .dsTextStyle(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(DSSpacing.xs)
                        }
                    }
                    .padding(DSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                            .fill(Color.white.opacity(0.08))
                    )
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
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .dsTextStyle(.caption1)
                .foregroundColor(.white)
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
