import SwiftUI

struct PoseAnalysisView: View {
    let image: UIImage
    @Environment(\.selectedAIModel) private var selectedModelBinding
    @StateObject private var viewModel: PoseAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    init(image: UIImage) {
        self.image = image
        _viewModel = StateObject(wrappedValue: PoseAnalysisViewModel(image: image, aiModel: .deepseek))
    }

    private var selectedModel: AIModel {
        get { selectedModelBinding.wrappedValue }
    }

    var body: some View {
        ZStack {
            Color.dsBackgroundSecondary.ignoresSafeArea()

            switch viewModel.phase {
            case .detecting, .analyzing:
                loadingView
            case .done:
                resultView
            case .error:
                errorView
            }
        }
        .onChange(of: selectedModelBinding.wrappedValue) { newModel in
            viewModel.aiModel = newModel
            Task { await viewModel.startAnalysis() }
        }
        .task {
            guard viewModel.phase != .done else { return }
            await viewModel.startAnalysis()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text(viewModel.phase == .detecting ? "正在检测姿态..." : "正在 AI 分析...")
                .dsTextStyle(.body)
                .foregroundColor(.dsLabelSecondary)
            Text("模型: \(selectedModel.rawValue)")
                .dsTextStyle(.footnote)
                .foregroundColor(.dsLabelSecondary)
        }
    }

    // MARK: - Result

    private var resultView: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                if selectedModel == .zhipu || selectedModel == .minimax, let edgeImg = viewModel.edgeCompositeImage {
                    Image(uiImage: edgeImg)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(DSCornerRadius.medium)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.top, DSSpacing.md)
                } else if let annotatedImage = viewModel.annotatedImage {
                    Image(uiImage: annotatedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(DSCornerRadius.medium)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.top, DSSpacing.md)
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
        VStack(spacing: DSSpacing.sm) {
            Text("体态数据")
                .dsTextStyle(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.lg)

            if let angles = viewModel.angles {
                AngleCard(
                    label: "头部侧倾",
                    value: angles.headForward.map { String(format: "%.1f°", $0) },
                    severity: severity(angles.headForward, for: .headForward)
                )
                AngleCard(
                    label: "高低肩差",
                    value: angles.shoulderDiff.map { String(format: "%.0f px", $0) },
                    severity: severity(angles.shoulderDiff, for: .shoulderDiff)
                )
                AngleCard(
                    label: "肩部倾斜",
                    value: angles.roundShoulder.map { String(format: "%.1f°", $0) },
                    severity: severity(angles.roundShoulder, for: .roundShoulder)
                )
                AngleCard(
                    label: "骨盆倾斜",
                    value: angles.pelvicTilt.map { String(format: "%.1f°", $0) },
                    severity: severity(angles.pelvicTilt, for: .pelvicTilt)
                )
                AngleCard(
                    label: "腿型偏移",
                    value: angles.legAlignment.map { String(format: "%.0f px", $0) },
                    severity: severity(angles.legAlignment, for: .legAlignment)
                )
            }
        }
    }

    // MARK: - AI Report

    private func aiReportSection(_ report: AnalysisReport) -> some View {
        VStack(spacing: DSSpacing.md) {
            Text("AI 分析报告")
                .dsTextStyle(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.lg)

            overallScoreCard(score: report.overallScore)

            ForEach(report.issues) { issue in
                issueCard(issue)
            }

            summaryCard(report.summary)
        }
    }

    private func overallScoreCard(score: Int) -> some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle()
                    .stroke(scoreColor(score).opacity(0.3), lineWidth: 6)
                    .frame(width: 64, height: 64)
                Text("\(score)")
                    .dsTextStyle(.title2)
                    .foregroundColor(scoreColor(score))
            }

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("综合评分")
                    .dsTextStyle(.headline)
                Text(score >= 80 ? "体态良好" : score >= 60 ? "存在一些问题" : "需要关注")
                    .dsTextStyle(.footnote)
                    .foregroundColor(.dsLabelSecondary)
            }

            Spacer()
        }
        .padding(DSSpacing.md)
        .background(Color.dsSurface)
        .cornerRadius(DSCornerRadius.medium)
        .padding(.horizontal, DSSpacing.md)
    }

    private func issueCard(_ issue: AnalysisReport.Issue) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(issue.name)
                    .dsTextStyle(.headline)
                Spacer()
                severityBadge(issue.severity)
            }
            Text(issue.description)
                .dsTextStyle(.footnote)
                .foregroundColor(.dsLabelSecondary)
                .lineSpacing(2)
        }
        .padding(DSSpacing.md)
        .background(Color.dsSurface)
        .cornerRadius(DSCornerRadius.medium)
        .padding(.horizontal, DSSpacing.md)
    }

    private func summaryCard(_ text: String) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.dsWarning)
            Text(text)
                .dsTextStyle(.body)
                .foregroundColor(.dsLabelSecondary)
            Spacer()
        }
        .padding(DSSpacing.md)
        .background(Color.dsSurface)
        .cornerRadius(DSCornerRadius.medium)
        .padding(.horizontal, DSSpacing.md)
    }

    private func severityBadge(_ severity: String) -> some View {
        let (label, color): (String, Color) = {
            switch severity {
            case "severe": return ("明显", .dsError)
            case "moderate": return ("中度", .dsWarning)
            case "mild": return ("轻度", .dsWarning.opacity(0.7))
            default: return ("未知", .dsLabelTertiary)
            }
        }()
        return Text(label)
            .dsTextStyle(.footnote)
            .foregroundColor(.white)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xxs)
            .background(color)
            .cornerRadius(DSCornerRadius.small)
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? .dsSuccess : score >= 60 ? .dsWarning : .dsError
    }

    // MARK: - Error

    private var errorView: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.dsWarning)
            Text(viewModel.error ?? "未知错误")
                .dsTextStyle(.body)
                .foregroundColor(.dsLabelSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.xxl)
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
                .dsTextStyle(.body)
                .foregroundColor(.dsLabel)
            Spacer()
            if let value {
                Text(value)
                    .dsTextStyle(.body)
                    .foregroundColor(.dsLabelSecondary)
            } else {
                Text("无数据")
                    .dsTextStyle(.footnote)
                    .foregroundColor(.dsLabelSecondary)
            }
            Text(severity.text)
                .dsTextStyle(.footnote)
                .foregroundColor(.white)
                .padding(.horizontal, DSSpacing.xs)
                .padding(.vertical, DSSpacing.xxs)
                .background(severity.color)
                .cornerRadius(DSCornerRadius.small)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.xs)
        .background(Color.dsSurface)
        .cornerRadius(DSCornerRadius.medium)
        .padding(.horizontal, DSSpacing.md)
    }
}

// MARK: - Severity helpers (pixel-based thresholds)

private enum AngleType {
    case headForward, shoulderDiff, roundShoulder, pelvicTilt, legAlignment
}

private func severity(_ value: Float?, for type: AngleType) -> (text: String, color: Color) {
    guard let value else { return ("无数据", .dsLabelTertiary) }
    switch type {
    case .headForward:
        if value <= 3 { return ("正常", .dsSuccess) }
        else if value <= 7 { return ("轻度", .dsWarning) }
        else { return ("明显", .dsError) }
    case .shoulderDiff:
        if value <= 30 { return ("正常", .dsSuccess) }
        else if value <= 60 { return ("轻度", .dsWarning) }
        else { return ("明显", .dsError) }
    case .roundShoulder:
        if value <= 3 { return ("正常", .dsSuccess) }
        else if value <= 7 { return ("轻度", .dsWarning) }
        else { return ("明显", .dsError) }
    case .pelvicTilt:
        if value <= 3 { return ("正常", .dsSuccess) }
        else if value <= 7 { return ("轻度", .dsWarning) }
        else { return ("明显", .dsError) }
    case .legAlignment:
        if value <= 25 { return ("正常", .dsSuccess) }
        else if value <= 45 { return ("轻度", .dsWarning) }
        else { return ("明显", .dsError) }
    }
}
