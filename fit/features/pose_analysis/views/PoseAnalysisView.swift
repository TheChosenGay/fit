import SwiftUI

struct PoseAnalysisView: View {
    let image: UIImage
    @StateObject private var viewModel: PoseAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    init(image: UIImage) {
        self.image = image
        _viewModel = StateObject(wrappedValue: PoseAnalysisViewModel(image: image))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            switch viewModel.phase {
            case .detecting, .analyzing:
                loadingView
            case .done:
                resultView
            case .error:
                errorView
            }
        }
        .task { await viewModel.startAnalysis() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(viewModel.phase == .detecting ? "正在检测姿态..." : "正在 AI 分析...")
                .font(.appBody)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Result

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let annotatedImage = viewModel.annotatedImage {
                    Image(uiImage: annotatedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }

                angleSection

                if let report = viewModel.report {
                    aiReportSection(report)
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Angle cards

    private var angleSection: some View {
        VStack(spacing: 12) {
            Text("体态数据")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            if let angles = viewModel.angles {
                AngleCard(
                    label: "头前伸",
                    value: angles.headForward.map { String(format: "%.1f°", $0) },
                    severity: severity(angles.headForward, for: .headForward)
                )
                AngleCard(
                    label: "高低肩差",
                    value: angles.shoulderDiff.map { String(format: "%.3f", $0) },
                    severity: severity(angles.shoulderDiff, for: .shoulderDiff)
                )
                AngleCard(
                    label: "圆肩",
                    value: angles.roundShoulder.map { String(format: "%.1f°", $0) },
                    severity: severity(angles.roundShoulder, for: .roundShoulder)
                )
                AngleCard(
                    label: "骨盆前倾",
                    value: angles.pelvicTilt.map { String(format: "%.1f°", $0) },
                    severity: severity(angles.pelvicTilt, for: .pelvicTilt)
                )
                AngleCard(
                    label: "腿型偏移",
                    value: angles.legAlignment.map { String(format: "%.3f", $0) },
                    severity: severity(angles.legAlignment, for: .legAlignment)
                )
            }
        }
    }

    // MARK: - AI Report

    private func aiReportSection(_ report: AnalysisReport) -> some View {
        VStack(spacing: 16) {
            Text("AI 分析报告")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            overallScoreCard(score: report.overallScore)

            ForEach(report.issues) { issue in
                issueCard(issue)
            }

            summaryCard(report.summary)
        }
    }

    private func overallScoreCard(score: Int) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(scoreColor(score).opacity(0.3), lineWidth: 6)
                    .frame(width: 64, height: 64)
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(scoreColor(score))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("综合评分")
                    .font(.appHeadline)
                Text(score >= 80 ? "体态良好" : score >= 60 ? "存在一些问题" : "需要关注")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func issueCard(_ issue: AnalysisReport.Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(issue.name)
                    .font(.appBody)
                    .fontWeight(.semibold)
                Spacer()
                severityBadge(issue.severity)
            }
            Text(issue.description)
                .font(.appCaption)
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func summaryCard(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            Text(text)
                .font(.appBody)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func severityBadge(_ severity: String) -> some View {
        let (label, color): (String, Color) = {
            switch severity {
            case "severe": return ("明显", .red)
            case "moderate": return ("中度", .orange)
            case "mild": return ("轻度", .yellow)
            default: return ("未知", .gray)
            }
        }()
        return Text(label)
            .font(.appCaption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? .green : score >= 60 ? .orange : .red
    }

    // MARK: - Error

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text(viewModel.error ?? "未知错误")
                .font(.appBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("重试") {
                Task { await viewModel.startAnalysis() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - AngleCard

private struct AngleCard: View {
    let label: String
    let value: String?
    let severity: (text: String, color: Color)

    var body: some View {
        HStack {
            Text(label)
                .font(.appBody)
                .foregroundColor(.primary)
            Spacer()
            if let value {
                Text(value)
                    .font(.appBody)
                    .foregroundColor(.secondary)
            } else {
                Text("无数据")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
            Text(severity.text)
                .font(.appCaption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(severity.color)
                .cornerRadius(6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }
}

// MARK: - Severity helpers

private enum AngleType {
    case headForward, shoulderDiff, roundShoulder, pelvicTilt, legAlignment
}

private func severity(_ value: Float?, for type: AngleType) -> (text: String, color: Color) {
    guard let value else { return ("无数据", .gray) }
    switch type {
    case .headForward:
        if value <= 5 { return ("正常", .green) }
        else if value <= 10 { return ("轻度", .yellow) }
        else { return ("明显", .red) }
    case .shoulderDiff:
        if value <= 0.01 { return ("正常", .green) }
        else if value <= 0.02 { return ("轻度", .yellow) }
        else { return ("明显", .red) }
    case .roundShoulder:
        if value <= 10 { return ("正常", .green) }
        else if value <= 15 { return ("轻度", .yellow) }
        else { return ("明显", .red) }
    case .pelvicTilt:
        if value <= 10 { return ("正常", .green) }
        else if value <= 15 { return ("轻度", .yellow) }
        else { return ("明显", .red) }
    case .legAlignment:
        if value <= 0.02 { return ("正常", .green) }
        else if value <= 0.03 { return ("轻度", .yellow) }
        else { return ("明显", .red) }
    }
}
