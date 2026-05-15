import SwiftUI

@available(iOS 17.0, *)
struct TrainingPlanCardView: View {
    let plan: TrainingPlan
    let todaySession: PlannedSession?

    private var currentWeek: Int {
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: plan.createdAt, to: Date()).weekOfYear ?? 0
        return min(weeks + 1, plan.durationWeeks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .dsTextStyle(.headline)
                        .foregroundColor(.white)
                    Text("目标：\(goalLabel(plan.targetGoal))")
                        .dsTextStyle(.caption2)
                        .foregroundColor(.dsLabelSecondary)
                }
                Spacer()
                Text("第\(currentWeek)/\(plan.durationWeeks)周")
                    .dsTextStyle(.caption1)
                    .foregroundColor(.dsPrimary)
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.dsPrimary.opacity(0.15))
                    .cornerRadius(DSCornerRadius.small)
            }

            if let session = todaySession {
                Divider().background(Color.white.opacity(0.1))

                Text("今日训练 · \(session.focusArea)")
                    .dsTextStyle(.caption1)
                    .foregroundColor(.dsLabelSecondary)

                ForEach(session.exercises, id: \.name) { exercise in
                    HStack(spacing: DSSpacing.xs) {
                        Text(exercise.name)
                            .dsTextStyle(.caption1)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(exercise.sets)组 × \(exercise.repsPerSet)次")
                            .dsTextStyle(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        if exercise.restSeconds > 0 {
                            Text("休\(exercise.restSeconds)s")
                                .dsTextStyle(.caption2)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }

                NavigationLink {
                    WorkoutSessionView()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始训练")
                    }
                    .dsTextStyle(.caption1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.xs)
                    .background(Color.dsSuccess)
                    .cornerRadius(DSCornerRadius.small)
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

    private func goalLabel(_ goal: String) -> String {
        switch goal {
        case "posture_correction": return "体态矫正"
        case "weight_loss": return "减脂"
        case "muscle_gain": return "增肌"
        case "general_fitness": return "综合健康"
        default: return goal
        }
    }
}
