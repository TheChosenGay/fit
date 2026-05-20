import Foundation
import SwiftData


@available(iOS 17.0, *)
protocol DietDataService {
    func saveMeal(_ meal: MealRecord, context: ModelContext) throws
    func fetchMeals(for date: Date, context: ModelContext) throws -> [MealRecord]
    func fetchMealsRange(from start: Date, to end: Date, context: ModelContext) throws -> [MealRecord]
    func fetchDailyNutrition(for date: Date, context: ModelContext) throws -> NutritionSummary
}

struct NutritionSummary {
    var totalCalories: Int = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
}

@available(iOS 17.0, *)
struct DefaultDietDataService: DietDataService {
    func saveMeal(_ meal: MealRecord, context: ModelContext) throws {
        context.insert(meal)
        try context.save()
    }

    func fetchMeals(for date: Date, context: ModelContext) throws -> [MealRecord] {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        var descriptor = FetchDescriptor<MealRecord>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        descriptor.predicate = #Predicate { $0.date >= dayStart && $0.date < dayEnd }
        return try context.fetch(descriptor)
    }

    func fetchMealsRange(from start: Date, to end: Date, context: ModelContext) throws -> [MealRecord] {
        let dayStart = Calendar.current.startOfDay(for: start)
        let dayEnd = Calendar.current.startOfDay(for: end)
        var descriptor = FetchDescriptor<MealRecord>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        descriptor.predicate = #Predicate { $0.date >= dayStart && $0.date < dayEnd }
        return try context.fetch(descriptor)
    }

    func fetchDailyNutrition(for date: Date, context: ModelContext) throws -> NutritionSummary {
        let meals = try fetchMeals(for: date, context: context)
        var summary = NutritionSummary()
        for meal in meals {
            summary.totalCalories += meal.totalCalories
            summary.proteinGrams += meal.proteinGrams
            summary.carbsGrams += meal.carbsGrams
            summary.fatGrams += meal.fatGrams
        }
        return summary
    }
}
