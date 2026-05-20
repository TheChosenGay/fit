import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct DietTabView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DietViewModel()
    @State private var showFoodCamera = false
    @State private var selectedMealType = "lunch"

    @Query private var profiles: [UserProfile]

    private let mealTypes: [(String, String, Color)] = [
        ("breakfast", "早餐", .orange),
        ("lunch", "午餐", .dsPrimary),
        ("dinner", "晚餐", .purple),
        ("snack", "加餐", .pink),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                // Header
                Text("饮食记录")
                    .dsTextStyle(.headline)
                    .foregroundColor(.dsLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.lg)

                // Nutrition summary
                nutritionSummaryCard

                // Today's meals
                VStack(spacing: DSSpacing.sm) {
                    HStack {
                        Text("今日餐食")
                            .dsTextStyle(.callout)
                            .foregroundColor(.dsLabel)
                        Spacer()
                        Button {
                            showFoodCamera = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("记录")
                            }
                            .dsTextStyle(.caption1)
                            .foregroundColor(.dsPrimary)
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)

                    // Meal type picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DSSpacing.xs) {
                            ForEach(mealTypes, id: \.0) { (key, label, color) in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedMealType = key
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: mealTypeIcon(key))
                                        Text(label)
                                    }
                                    .dsTextStyle(.caption1)
                                    .foregroundColor(selectedMealType == key ? .white : color)
                                    .padding(.horizontal, DSSpacing.sm)
                                    .padding(.vertical, DSSpacing.xxs)
                                    .background(
                                        Capsule()
                                            .fill(selectedMealType == key ? color : color.opacity(0.12))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, DSSpacing.lg)
                    }

                    MealListView(mealType: selectedMealType)
                        .padding(.horizontal, DSSpacing.lg)
                }
            }
            .padding(.bottom, DSSpacing.huge)
        }
        .background(Color.dsBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $showFoodCamera) {
            FoodCameraView(mealType: selectedMealType)
                .navigationBarHidden(true)
        }
        .overlay {
            if viewModel.isAnalyzing {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: DSSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("正在分析食物...")
                        .dsTextStyle(.body)
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Nutrition summary

    private var nutritionSummaryCard: some View {
        VStack(spacing: DSSpacing.md) {
            Text("今日营养")
                .dsTextStyle(.headline)
                .foregroundColor(.dsLabel)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DSSpacing.xl) {
                nutritionProgress(value: 0, target: 2000, unit: "千卡", label: "热量", color: .dsWarning, icon: "flame.fill")
                nutritionProgress(value: 0, target: 80, unit: "g", label: "蛋白质", color: .dsPrimary, icon: "circle.hexagonpath.fill")
                nutritionProgress(value: 0, target: 250, unit: "g", label: "碳水", color: .dsSecondary, icon: "chart.bar.fill")
                nutritionProgress(value: 0, target: 65, unit: "g", label: "脂肪", color: .dsError, icon: "drop.triangle.fill")
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

    private func nutritionProgress(value: Int, target: Int, unit: String, label: String, color: Color, icon: String) -> some View {
        let ratio = min(Double(value) / Double(target), 1.0)

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 4)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundColor(color)
                Text(unit)
                    .dsTextStyle(.caption2)
                    .foregroundColor(.dsLabelTertiary)
            }

            Text(label)
                .dsTextStyle(.caption2)
                .foregroundColor(.dsLabelTertiary)
        }
    }

    private func mealTypeIcon(_ type: String) -> String {
        switch type {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snack": return "cup.and.saucer.fill"
        default: return "fork.knife"
        }
    }
}

// MARK: - Meal list (today's meals for a specific meal type)

@available(iOS 17.0, *)
private struct MealListView: View {
    let mealType: String

    @Query private var meals: [MealRecord]

    init(mealType: String) {
        self.mealType = mealType
        let dayStart = Calendar.current.startOfDay(for: Date())
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        _meals = Query(
            filter: #Predicate { $0.date >= dayStart && $0.date < dayEnd && $0.mealType == mealType },
            sort: \MealRecord.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        if meals.isEmpty {
            VStack(spacing: DSSpacing.xs) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundColor(.dsLabelTertiary.opacity(0.4))
                Text("暂无\(mealTypeLabel)记录")
                    .dsTextStyle(.caption1)
                    .foregroundColor(.dsLabelTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                    .fill(Color.dsSurfaceSecondary)
            )
        } else {
            ForEach(meals) { meal in
                mealCard(meal)
            }
        }
    }

    private var mealTypeLabel: String {
        switch mealType {
        case "breakfast": return "早餐"
        case "lunch": return "午餐"
        case "dinner": return "晚餐"
        case "snack": return "加餐"
        default: return "餐食"
        }
    }

    private func mealCard(_ meal: MealRecord) -> some View {
        HStack(spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.foodDescription)
                    .dsTextStyle(.body)
                    .foregroundColor(.dsLabel)
                    .lineLimit(2)

                HStack(spacing: DSSpacing.sm) {
                    HStack(spacing: 2) {
                        Text("\(meal.totalCalories)")
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundColor(.dsWarning)
                        Text(" 千卡")
                            .dsTextStyle(.caption2)
                            .foregroundColor(.dsLabelTertiary)
                    }

                    HStack(spacing: 2) {
                        Text(String(format: "%.0f", meal.proteinGrams))
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundColor(.dsPrimary)
                        Text("g 蛋白")
                            .dsTextStyle(.caption2)
                            .foregroundColor(.dsLabelTertiary)
                    }
                }
            }

            Spacer()

            Text(meal.createdAt, style: .time)
                .dsTextStyle(.caption2)
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
