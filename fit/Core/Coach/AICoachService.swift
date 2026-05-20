import Foundation

// MARK: - Protocol

@available(iOS 17.0, *)
protocol AICoachService {
    func dailyBriefing(context: CoachContext) async throws -> CoachBriefing
    func realTimeFeedback(context: CoachContext, exerciseName: String, formScore: Int, recentReps: Int) async throws -> String
    func weeklyReport(context: CoachContext, poseHistory: [PoseAnalysisRecord], workoutHistory: [WorkoutSession]) async throws -> CoachReport
    func preWorkoutAdvice(context: CoachContext, supportedExercises: [String]) async throws -> WorkoutAdvice
}

// MARK: - DeepSeek implementation

@available(iOS 17.0, *)
final class DeepSeekAICoachService: AICoachService {
    nonisolated static let shared = DeepSeekAICoachService()
    private init() {}
    nonisolated let aiService = FitGenericAIService(type:.deepseek)
    // MARK: Daily briefing

    func dailyBriefing(context: CoachContext) async throws -> CoachBriefing {
        let systemPrompt = """
        你是一位专业的AI健身私教，拥有用户完整的健康数据。用中文与用户交流，语气亲切专业。
        用户数据会以结构化方式提供，请根据这些数据给出个性化建议。
        """

        let userPrompt = """
        请根据以下用户数据，生成今日训练简报。返回严格JSON（不要markdown代码块标记）：

        \(context.userContext)

        返回格式：
        {"greeting":"早上好！根据你昨天的训练情况...","health_summary":"今日已步行X步...","today_advice":"今天的训练重点是...","motivation_quote":"激励语"}
        """

        let request = FitAIRequest(
            model: "deepseek-chat",
            maxTokens: 1024,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt),
            ]
        )

        let text:String = try await aiService.query(req: request)

        let jsonText = stripMarkdownCodeBlock(text)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIAnalysisError.invalidJSON
        }

        return try JSONDecoder().decode(CoachBriefing.self, from: jsonData)
    }

    // MARK: Real-time feedback

    func realTimeFeedback(context: CoachContext, exerciseName: String, formScore: Int, recentReps: Int) async throws -> String {
        let systemPrompt = "你是一位实时健身教练。给出简短的中文指导，严格控制在1-2句话以内，直接告诉用户如何调整动作。"

        let userPrompt = """
        用户当前数据：
        \(context.userContext)

        当前动作：\(exerciseName)
        当前完成：\(recentReps) 次
        动作评分：\(formScore)/100

        请给出实时的简短指导（1-2句话），关注动作质量和安全。如果评分低于60，指出问题并给出纠正建议。如果评分80以上，给予鼓励。
        只返回指导文字，不要JSON格式。
        """

        let request = FitAIRequest(
            model: "deepseek-chat",
            maxTokens: 200,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt),
            ]
        )

        let text = try await aiService.query(req: request)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Weekly report

    func weeklyReport(context: CoachContext, poseHistory: [PoseAnalysisRecord], workoutHistory: [WorkoutSession]) async throws -> CoachReport {
        let systemPrompt = """
        你是一位专业的AI健身私教。根据用户一周的训练和体态数据，生成周报。用中文回答，严格返回JSON格式。
        """

        let poseSummary = poseHistory.map { r in
            "\(r.date.formatted(date: .abbreviated, time: .omitted)): 评分\(r.overallScore)"
        }.joined(separator: ", ")

        let workoutSummary = workoutHistory.map { s in
            "\(s.date.formatted(date: .abbreviated, time: .omitted)): \(s.totalReps)次 评分\(s.averageFormScore)"
        }.joined(separator: ", ")

        let userPrompt = """
        \(context.userContext)

        本周体态记录：\(poseSummary)
        本周训练记录：\(workoutSummary)

        请返回严格JSON：
        {"summary":"本周训练总结...","improvements":["改善点1","改善点2"],"recommendations":["建议1","建议2"]}
        """

        let request = FitAIRequest(
            model: "deepseek-chat",
            maxTokens: 1024,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt),
            ]
        )

        let text = try await aiService.query(req: request)

        let jsonText = stripMarkdownCodeBlock(text)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIAnalysisError.invalidJSON
        }

        return try JSONDecoder().decode(CoachReport.self, from: jsonData)
    }

    // MARK: - Pre-workout advice

    func preWorkoutAdvice(context: CoachContext, supportedExercises: [String]) async throws -> WorkoutAdvice {
        let systemPrompt = """
        你是一位专业的AI健身私教。用户即将开始训练，请根据TA最近一周的健康数据、训练记录和饮食情况，判断今天是否适合训练，并给出建议。

        评估要点：
        1. 睡眠不足（<6小时）、HRV显著偏低（<30ms）、静息心率异常偏高 → 建议休息
        2. 连续训练天数过多、最近训练强度太大 → 建议轻量训练或休息
        3. 睡眠充足、HRV正常、最近训练间隔合理 → 鼓励训练
        4. 饮食中蛋白质不足 → 提醒补充

        返回严格JSON（不要markdown）：
        {"should_train":true/false,"reason":"判断依据，2-3句话","suggested_focus":"今天建议重点训练的动作/肌群","warnings":["警告1","警告2"]}

        若无特殊风险，warnings 可省略。suggested_focus 从以下可选动作中挑选：\(supportedExercises.joined(separator: "、"))
        """

        let request = FitAIRequest(
            model: "deepseek-chat",
            maxTokens: 512,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: context.userContext),
            ]
        )

        let text = try await aiService.query(req: request)

        let jsonText = stripMarkdownCodeBlock(text)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIAnalysisError.invalidJSON
        }

        return try JSONDecoder().decode(WorkoutAdvice.self, from: jsonData)
    }

    // MARK: - Helpers

    private func stripMarkdownCodeBlock(_ text: String) -> String {
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

