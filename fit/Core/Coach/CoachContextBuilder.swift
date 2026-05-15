import Foundation

@available(iOS 17.0, *)
enum CoachContextBuilder {

    // MARK: - Daily brief context

    static func buildDailyContext(
        profile: UserProfile?,
        healthData: HealthKitDayData?,
        recentPoses: [PoseAnalysisRecord],
        recentWorkouts: [WorkoutSession],
        todayMeals: [MealRecord],
        activePlan: TrainingPlan?,
        todaySession: PlannedSession?
    ) -> CoachContext {
        let systemPrompt = """
        你是一位专业的AI健身私教，名叫"小Fit"。你拥有用户完整的健康数据，包括体态分析、训练记录、饮食和健康指标。
        用中文与用户交流，语气亲切、专业、鼓励。根据数据给出个性化、可操作的建议。
        """

        var parts: [String] = []

        // Profile
        if let profile {
            parts.append(buildProfileSection(profile))
        }

        // HealthKit
        if let health = healthData {
            parts.append(buildHealthSection(health))
        }

        // Recent poses
        if !recentPoses.isEmpty {
            parts.append(buildPoseSection(recentPoses))
        }

        // Recent workouts
        if !recentWorkouts.isEmpty {
            parts.append(buildWorkoutSection(recentWorkouts))
        }

        // Today's meals
        if !todayMeals.isEmpty {
            parts.append(buildMealSection(todayMeals))
        }

        // Training plan
        if let plan = activePlan {
            parts.append(buildPlanSection(plan, todaySession: todaySession))
        }

        let userContext = parts.joined(separator: "\n\n---\n\n")

        return CoachContext(systemPrompt: systemPrompt, userContext: userContext)
    }

    // MARK: - Real-time feedback context

    static func buildRealTimeContext(
        profile: UserProfile?,
        exerciseName: String,
        formScore: Int,
        recentReps: Int
    ) -> CoachContext {
        let systemPrompt = "你是一位实时健身教练。给出简短的中文指导，1-2句话。"
        var parts: [String] = []

        if let profile {
            parts.append("用户目标：\(fitnessGoalLabel(profile.fitnessGoal ?? "general_fitness"))")
        }
        parts.append("当前动作：\(exerciseName)")
        parts.append("已完成次数：\(recentReps)")
        parts.append("当前动作评分：\(formScore)/100")

        let userContext = parts.joined(separator: "\n")

        return CoachContext(systemPrompt: systemPrompt, userContext: userContext)
    }

    // MARK: - Weekly report context

    static func buildWeeklyContext(
        profile: UserProfile?,
        healthData: [HealthKitDayData],
        poseHistory: [PoseAnalysisRecord],
        workoutHistory: [WorkoutSession],
        meals: [MealRecord]
    ) -> CoachContext {
        let systemPrompt = "你是一位专业的AI健身私教。根据用户一周的数据生成周报。用中文给出详细分析和下周建议。"
        var parts: [String] = []

        if let profile {
            parts.append(buildProfileSection(profile))
        }

        if !healthData.isEmpty {
            let avgSteps = healthData.compactMap { $0.steps }.reduce(0, +) / max(healthData.count, 1)
            let totalCal = healthData.reduce(0.0) { $0 + $1.activeEnergyKcal }
            parts.append("本周平均步数：\(avgSteps)/天，总消耗：\(Int(totalCal))千卡")
        }

        if !poseHistory.isEmpty {
            let avgScore = poseHistory.map(\.overallScore).reduce(0, +) / max(poseHistory.count, 1)
            parts.append("本周体态分析\(poseHistory.count)次，平均评分：\(avgScore)")
        }

        if !workoutHistory.isEmpty {
            let totalReps = workoutHistory.map(\.totalReps).reduce(0, +)
            let totalMinutes = workoutHistory.map(\.durationSeconds).reduce(0, +) / 60
            parts.append("本周训练\(workoutHistory.count)次，总次数：\(totalReps)，总时长：\(totalMinutes)分钟")
        }

        let userContext = parts.joined(separator: "\n\n")

        return CoachContext(systemPrompt: systemPrompt, userContext: userContext)
    }

    // MARK: - Private builders

    private static func buildProfileSection(_ p: UserProfile) -> String {
        let sex = switch p.biologicalSex {
        case "male": "男"
        case "female": "女"
        default: "未设置"
        }
        let age: String = {
            guard let dob = p.dateOfBirth else { return "未知" }
            let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
            return "\(years)岁"
        }()
        return """
        用户档案：
        - 姓名：\(p.name)
        - 性别：\(sex)，年龄：\(age)
        - 身高：\(String(format: "%.0f", p.heightCm ?? 0))cm，体重：\(String(format: "%.1f", p.weightKg ?? 0))kg
        - 健身目标：\(fitnessGoalLabel(p.fitnessGoal ?? "general_fitness"))
        - 活动水平：\(activityLevelLabel(p.activityLevel ?? "moderate"))
        """
    }

    private static func buildHealthSection(_ h: HealthKitDayData) -> String {
        """
        今日健康数据：
        - 步数：\(h.steps) 步
        - 活动能量：\(String(format: "%.0f", h.activeEnergyKcal)) 千卡
        - 平均心率：\(h.heartRateAvg.map { String(format: "%.0f", $0) } ?? "无数据") bpm
        - 睡眠：\(h.sleepHours.map { String(format: "%.1f", $0) } ?? "无数据") 小时
        """
    }

    private static func buildPoseSection(_ poses: [PoseAnalysisRecord]) -> String {
        let items = poses.prefix(3).map { r in
            "\(r.date.formatted(date: .abbreviated, time: .omitted)): 评分\(r.overallScore) - \(r.summary)"
        }
        return "最近体态分析：\n" + items.joined(separator: "\n")
    }

    private static func buildWorkoutSection(_ workouts: [WorkoutSession]) -> String {
        let items = workouts.prefix(5).map { s in
            "\(s.date.formatted(date: .abbreviated, time: .shortened)): \(s.totalReps)次，评分\(s.averageFormScore)，时长\(s.durationSeconds/60)分钟"
        }
        return "最近训练记录：\n" + items.joined(separator: "\n")
    }

    private static func buildMealSection(_ meals: [MealRecord]) -> String {
        let items = meals.map { m in
            let typeLabel = switch m.mealType {
            case "breakfast": "早餐"
            case "lunch": "午餐"
            case "dinner": "晚餐"
            case "snack": "加餐"
            default: "餐食"
            }
            return "\(typeLabel): \(m.foodDescription) (\(m.totalCalories)千卡)"
        }
        return "今日饮食：\n" + items.joined(separator: "\n")
    }

    private static func buildPlanSection(_ plan: TrainingPlan, todaySession: PlannedSession?) -> String {
        let currentWeek = min(Calendar.current.dateComponents([.weekOfYear], from: plan.createdAt, to: Date()).weekOfYear ?? 0, plan.durationWeeks)
        var text = "训练计划：\(plan.name)（目标：\(fitnessGoalLabel(plan.targetGoal ?? "general_fitness"))，第\(currentWeek)/\(plan.durationWeeks)周）"
        if let session = todaySession {
            let exercises = session.exercises.map { "\($0.name) \($0.sets)组×\($0.repsPerSet)次" }.joined(separator: "、")
            text += "\n今日训练：\(session.focusArea ?? "全身") - \(exercises)"
        }
        return text
    }

    private static func fitnessGoalLabel(_ goal: String) -> String {
        switch goal {
        case "posture_correction": return "体态矫正"
        case "weight_loss": return "减脂"
        case "muscle_gain": return "增肌"
        case "general_fitness": return "综合健康"
        default: return goal
        }
    }

    private static func activityLevelLabel(_ level: String) -> String {
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
