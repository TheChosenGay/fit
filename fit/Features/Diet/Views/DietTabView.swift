import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct DietTabView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DietViewModel()
    @State private var showFoodCamera = false
    @State private var selectedMealType = "lunch"

    @Query private var profiles: [UserProfile]

    private let mealTypes: [(String, String)] = [
        ("breakfast", "早餐"),
        ("lunch", "午餐"),
        ("dinner", "晚餐"),
        ("snack", "加餐"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Nutrition summary
                nutritionSummaryCard

                // Today's meals header
                HStack {
                    Text("今日餐食")
                        .dsTextStyle(.body)
                        .foregroundColor(.white)

                    Spacer()

                    Picker(selection: $selectedMealType) {
                        ForEach(mealTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                    .tint(.dsPrimary)

                    Button {
                        showFoodCamera = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.dsPrimary)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)

                // Meal list from today
                MealListView(mealType: selectedMealType)
                    .padding(.horizontal, DSSpacing.lg)
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
        VStack(spacing: DSSpacing.sm) {
            Text("今日营养")
                .dsTextStyle(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DSSpacing.xl) {
                nutritionItem(value: "0", unit: "千卡", label: "热量", color: .dsWarning)
                nutritionItem(value: "0", unit: "g", label: "蛋白质", color: .dsPrimary)
                nutritionItem(value: "0", unit: "g", label: "碳水", color: .dsSecondary)
                nutritionItem(value: "0", unit: "g", label: "脂肪", color: .dsError)
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, DSSpacing.lg)
    }

    private func nutritionItem(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(color)
                Text(unit)
                    .dsTextStyle(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(label)
                .dsTextStyle(.caption2)
                .foregroundColor(.white.opacity(0.5))
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
            Text("暂无\(mealTypeLabel)记录")
                .dsTextStyle(.caption1)
                .foregroundColor(.white.opacity(0.5))
                .padding(DSSpacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .fill(Color.white.opacity(0.08))
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
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: DSSpacing.xs) {
                    Text("\(meal.totalCalories)千卡")
                        .foregroundColor(.dsWarning)
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text("蛋白质 \(String(format: "%.0f", meal.proteinGrams))g")
                        .foregroundColor(.dsPrimary)
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text("碳水 \(String(format: "%.0f", meal.carbsGrams))g")
                        .foregroundColor(.dsSecondary)
                }
                .dsTextStyle(.caption2)
            }

            Spacer()

            Text(meal.createdAt, style: .time)
                .dsTextStyle(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.white.opacity(0.08))
        )
    }
}
