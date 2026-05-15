import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct TrainingPlanGenerationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var planName: String = ""
    @State private var targetGoal: String = "general_fitness"
    @State private var durationWeeks: Int = 4
    @State private var sessionsPerWeek: Int = 3
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private let goalOptions: [(String, String)] = [
        ("posture_correction", "体态矫正"),
        ("weight_loss", "减脂"),
        ("muscle_gain", "增肌"),
        ("general_fitness", "综合健康"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Basic info
                SectionCard(title: "基本信息") {
                    VStack(spacing: DSSpacing.md) {
                        HStack {
                            Text("计划名称")
                                .dsTextStyle(.body)
                                .foregroundColor(.white)
                            Spacer()
                            TextField("例如：4周增肌计划", text: $planName)
                                .multilineTextAlignment(.trailing)
                                .dsTextStyle(.body)
                                .foregroundColor(.white)
                        }

                        HStack {
                            Text("健身目标")
                                .dsTextStyle(.body)
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $targetGoal) {
                                ForEach(goalOptions, id: \.0) { option in
                                    Text(option.1).tag(option.0)
                                }
                            }
                            .tint(.dsPrimary)
                        }

                        HStack {
                            Text("持续周数")
                                .dsTextStyle(.body)
                                .foregroundColor(.white)
                            Spacer()
                            Stepper("\(durationWeeks) 周", value: $durationWeeks, in: 1...24)
                                .dsTextStyle(.body)
                                .foregroundColor(.dsPrimary)
                        }

                        HStack {
                            Text("每周训练")
                                .dsTextStyle(.body)
                                .foregroundColor(.white)
                            Spacer()
                            Stepper("\(sessionsPerWeek) 次", value: $sessionsPerWeek, in: 1...7)
                                .dsTextStyle(.body)
                                .foregroundColor(.dsPrimary)
                        }
                    }
                }

                // Generate button
                Button {
                    Task { await generatePlan() }
                } label: {
                    HStack(spacing: DSSpacing.xs) {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isGenerating ? "正在生成..." : "生成训练计划")
                            .dsTextStyle(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isGenerating ? Color.dsPrimary.opacity(0.5) : Color.dsPrimary)
                    .cornerRadius(DSCornerRadius.medium)
                }
                .disabled(isGenerating || planName.isEmpty)
                .padding(.horizontal, DSSpacing.lg)

                if let error = errorMessage {
                    Text(error)
                        .dsTextStyle(.caption1)
                        .foregroundColor(.dsError)
                        .padding(.horizontal, DSSpacing.lg)
                }
            }
            .padding(.bottom, DSSpacing.huge)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .navigationTitle("创建训练计划")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Generate

    private func generatePlan() async {
        isGenerating = true
        errorMessage = nil

        do {
            let prompt = """
            你是一位专业健身教练。根据以下要求，生成一个完整的周训练计划。返回严格JSON格式（不要markdown代码块标记）：

            计划名称：\(planName)
            健身目标：\(goalLabel(targetGoal))
            持续周数：\(durationWeeks)周
            每周训练次数：\(sessionsPerWeek)次

            请生成第一周的\(sessionsPerWeek)次训练，每次训练包含3-5个动作。
            返回格式：
            {
              "sessions": [
                {
                  "day_of_week": 1,
                  "focus_area": "胸部+三头肌",
                  "warmup_minutes": 5,
                  "exercises": [
                    {"name": "俯卧撑", "sets": 4, "reps_per_set": 12, "rest_seconds": 60, "target_body_region": "chest", "coaching_cues": ["核心收紧", "身体保持直线"]}
                  ]
                }
              ]
            }
            """

            let request = PlanGenRequest(
                model: "deepseek-chat",
                maxTokens: 2048,
                messages: [
                    .init(role: "system", content: "你是一位专业健身教练。用中文回答，严格返回JSON格式。"),
                    .init(role: "user", content: prompt),
                ]
            )

            let body = try JSONEncoder().encode(request)
            let response: PlanGenResponse = try await NetworkService.shared.request(
                url: ServiceEndpoint.DeepSeek.chatCompletions,
                headers: ["Authorization": "Bearer \(Secrets.deepseekAPIKey)"],
                body: body
            )

            guard let text = response.choices.first?.message.content else {
                errorMessage = "AI 未返回内容"
                isGenerating = false
                return
            }

            let jsonText = stripMarkdown(text)
            guard let jsonData = jsonText.data(using: .utf8) else {
                errorMessage = "响应格式异常"
                isGenerating = false
                return
            }

            let generated = try JSONDecoder().decode(PlanGenResult.self, from: jsonData)

            // Save to SwiftData
            let plan = TrainingPlan()
            plan.name = planName
            plan.targetGoal = targetGoal
            plan.durationWeeks = durationWeeks
            plan.sessionsPerWeek = sessionsPerWeek
            plan.isActive = true

            for (index, sessionData) in generated.sessions.enumerated() {
                let session = PlannedSession()
                session.dayOfWeek = sessionData.dayOfWeek > 0 ? sessionData.dayOfWeek : index + 1
                session.focusArea = sessionData.focusArea
                session.warmupMinutes = sessionData.warmupMinutes > 0 ? sessionData.warmupMinutes : 5
                session.exercises = sessionData.exercises.map { ex in
                    PlannedExercise(
                        name: ex.name,
                        sets: ex.sets,
                        repsPerSet: ex.repsPerSet,
                        restSeconds: ex.restSeconds,
                        targetBodyRegion: ex.targetBodyRegion,
                        coachingCues: ex.coachingCues
                    )
                }
                plan.sessions?.append(session)
            }

            modelContext.insert(plan)
            try modelContext.save()

            dismiss()
        } catch {
            errorMessage = "生成失败: \(error.localizedDescription)"
        }

        isGenerating = false
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

    private func stripMarkdown(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
        }
        if t.hasSuffix("```") {
            t = String(t.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }
}

// MARK: - SectionCard helper

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(title)
                .dsTextStyle(.headline)
                .foregroundColor(.white)
            content
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, DSSpacing.lg)
    }
}

// MARK: - API models

private struct PlanGenRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct PlanGenResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct PlanGenResult: Codable {
    let sessions: [GenSession]

    struct GenSession: Codable {
        let dayOfWeek: Int
        let focusArea: String
        let warmupMinutes: Int
        let exercises: [GenExercise]

        enum CodingKeys: String, CodingKey {
            case dayOfWeek = "day_of_week"
            case focusArea = "focus_area"
            case warmupMinutes = "warmup_minutes"
            case exercises
        }
    }

    struct GenExercise: Codable {
        let name: String
        let sets: Int
        let repsPerSet: Int
        let restSeconds: Int
        let targetBodyRegion: String
        let coachingCues: [String]

        enum CodingKeys: String, CodingKey {
            case name, sets
            case repsPerSet = "reps_per_set"
            case restSeconds = "rest_seconds"
            case targetBodyRegion = "target_body_region"
            case coachingCues = "coaching_cues"
        }
    }
}
