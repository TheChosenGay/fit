import Foundation

@available(iOS 17.0, *)
enum CoachContextBuilder {

    // MARK: - Daily brief context

    static func buildDailyContext(
        profile: UserProfile?,
        healthData: DailyHealthData?,
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

        // Health (from SwiftData DailyHealthData)
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
        healthData: [DailyHealthData],
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
            let avgSteps = healthData.map(\.steps).reduce(0, +) / max(healthData.count, 1)
            let totalCal = healthData.reduce(0.0) { $0 + $1.activeEnergyKcal }
            let avgSleep = healthData.compactMap(\.sleepHours).reduce(0.0, +) / Double(max(healthData.compactMap(\.sleepHours).count, 1))
            let avgHRV = healthData.compactMap(\.heartRateVariability).reduce(0.0, +) / Double(max(healthData.compactMap(\.heartRateVariability).count, 1))
            let totalExerciseMin = healthData.map(\.exerciseMinutes).reduce(0, +)
            parts.append("本周平均步数：\(avgSteps)/天，总消耗：\(Int(totalCal))千卡，平均睡眠：\(String(format: "%.1f", avgSleep))小时，平均HRV：\(String(format: "%.0f", avgHRV))ms，锻炼总时长：\(totalExerciseMin)分钟")
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

    // MARK: - Pre-workout context

    static func buildPreWorkoutContext(
        profile: UserProfile?,
        healthData: [DailyHealthData],
        recentWorkouts: [WorkoutSession],
        recentMeals: [MealRecord]
    ) -> CoachContext {
        let systemPrompt = "你是一位专业AI健身私教，根据用户近一周数据判断今天是否适合训练。"
        var parts: [String] = []

        if let profile {
            parts.append(buildProfileSection(profile))
        }

        // Last 7 days health summary
        if !healthData.isEmpty {
            let avgSleep = healthData.compactMap(\.sleepHours).reduce(0.0, +) / Double(max(healthData.compactMap(\.sleepHours).count, 1))
            let avgHRV = healthData.compactMap(\.heartRateVariability).reduce(0.0, +) / Double(max(healthData.compactMap(\.heartRateVariability).count, 1))
            let avgRestHR = healthData.compactMap(\.restingHeartRate).reduce(0.0, +) / Double(max(healthData.compactMap(\.restingHeartRate).count, 1))
            let avgDeep = healthData.compactMap(\.deepSleepHours).reduce(0.0, +) / Double(max(healthData.compactMap(\.deepSleepHours).count, 1))
            let totalExercise = healthData.map(\.exerciseMinutes).reduce(0, +)

            let todayHealth = healthData.first { Calendar.current.isDateInToday($0.date) }
            let todaySleep = todayHealth?.sleepHours
            let todayHRV = todayHealth?.heartRateVariability

            var healthLines: [String] = [
                "近7天平均：睡眠 \(String(format: "%.1f", avgSleep))h，深睡 \(String(format: "%.1f", avgDeep))h，HRV \(String(format: "%.0f", avgHRV))ms，静息心率 \(String(format: "%.0f", avgRestHR))bpm",
                "7天总锻炼：\(totalExercise)分钟",
            ]
            if let sleep = todaySleep {
                healthLines.append("昨晚睡眠：\(String(format: "%.1f", sleep))小时")
            }
            if let hrv = todayHRV {
                healthLines.append("今早HRV：\(String(format: "%.0f", hrv))ms")
            }
            parts.append(healthLines.joined(separator: "\n"))
        }

        // Recent workouts
        if !recentWorkouts.isEmpty {
            let last7 = recentWorkouts.filter {
                Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 8 <= 7
            }
            if !last7.isEmpty {
                let sessions = last7.sorted(by: { $0.date > $1.date })
                let history = sessions.map { s in
                    "\(s.date.formatted(date: .numeric, time: .omitted)): \(s.totalReps)次 评分\(s.averageFormScore ?? 0) \(s.durationSeconds/60)分钟"
                }.joined(separator: "\n")
                let consecutiveDays = maxConsecutiveDays(sessions.map(\.date))
                parts.append("最近7天训练（连续\(consecutiveDays)天）：\n\(history)")
            }
        }

        // Recent meals
        if !recentMeals.isEmpty {
            let avgCal = recentMeals.map(\.totalCalories).reduce(0, +) / max(recentMeals.count, 1)
            let avgProtein = recentMeals.map(\.proteinGrams).reduce(0.0, +) / Double(max(recentMeals.count, 1))
            parts.append("近7天饮食：日均 \(avgCal)千卡，蛋白质 \(String(format: "%.0f", avgProtein))g/天")
        }

        let userContext = parts.joined(separator: "\n\n---\n\n")

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

    private static func buildHealthSection(_ h: DailyHealthData) -> String {
        var lines: [String] = []

        // Activity
        lines.append("活动：步数 \(h.steps)，活动能量 \(String(format: "%.0f", h.activeEnergyKcal))千卡")
        if let basal = h.basalEnergyKcal {
            lines.append("基础代谢 \(String(format: "%.0f", basal))千卡")
        }
        if h.exerciseMinutes > 0 {
            lines.append("锻炼 \(h.exerciseMinutes)分钟，站立 \(h.standMinutes)分钟")
        }
        if let dist = h.distanceWalkedKm, dist > 0 {
            lines.append("步行距离 \(String(format: "%.1f", dist))公里")
        }

        // Heart Rate
        var hrParts: [String] = []
        if let avg = h.heartRateAvg { hrParts.append("平均心率 \(String(format: "%.0f", avg))bpm") }
        if let min = h.heartRateMin { hrParts.append("最低 \(String(format: "%.0f", min))bpm") }
        if let max = h.heartRateMax { hrParts.append("最高 \(String(format: "%.0f", max))bpm") }
        if let rest = h.restingHeartRate { hrParts.append("静息心率 \(String(format: "%.0f", rest))bpm") }
        if !hrParts.isEmpty { lines.append("心率：" + hrParts.joined(separator: "，")) }

        if let hrv = h.heartRateVariability {
            lines.append("HRV: \(String(format: "%.0f", hrv))ms（\(hrvStatus(hrv))）")
        }
        if let walkingHR = h.walkingHeartRateAvg {
            lines.append("步行平均心率：\(String(format: "%.0f", walkingHR))bpm")
        }

        // Sleep
        if let sleepHours = h.sleepHours {
            var sleepStr = "睡眠：总计 \(String(format: "%.1f", sleepHours))小时"
            var stageParts: [String] = []
            if let deep = h.deepSleepHours, deep > 0 { stageParts.append("深睡 \(String(format: "%.1f", deep))h") }
            if let rem = h.remSleepHours, rem > 0 { stageParts.append("REM \(String(format: "%.1f", rem))h") }
            if let core = h.coreSleepHours, core > 0 { stageParts.append("核心 \(String(format: "%.1f", core))h") }
            if !stageParts.isEmpty { sleepStr += "（" + stageParts.joined(separator: "，") + "）" }
            if let start = h.sleepStartTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                sleepStr += "，入睡 \(formatter.string(from: start))"
            }
            if let end = h.sleepEndTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                sleepStr += "，起床 \(formatter.string(from: end))"
            }
            if h.sleepInterruptions > 0 {
                sleepStr += "，中断 \(h.sleepInterruptions) 次"
            }
            lines.append(sleepStr)
        }

        // Other vitals
        var vitals: [String] = []
        if let resp = h.respiratoryRateAvg { vitals.append("呼吸频率 \(String(format: "%.1f", resp))次/分") }
        if let spo2 = h.bloodOxygenAvg { vitals.append("血氧 \(String(format: "%.0f", spo2))%") }
        if !vitals.isEmpty { lines.append("其他：" + vitals.joined(separator: "，")) }

        return lines.joined(separator: "\n")
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

    // MARK: - Labels

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

    private static func hrvStatus(_ hrv: Double) -> String {
        switch hrv {
        case 0..<30: return "偏低，恢复不足"
        case 30..<50: return "一般"
        case 50..<80: return "良好"
        default: return "优秀"
        }
    }

    private static func maxConsecutiveDays(_ dates: [Date]) -> Int {
        let sorted = dates.map { Calendar.current.startOfDay(for: $0) }.sorted()
        guard !sorted.isEmpty else { return 0 }
        var maxRun = 1
        var current = 1
        for i in 1..<sorted.count {
            if Calendar.current.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day == 1 {
                current += 1
                maxRun = max(maxRun, current)
            } else {
                current = 1
            }
        }
        return maxRun
    }
}
