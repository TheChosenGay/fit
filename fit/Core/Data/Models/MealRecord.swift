import Foundation
import SwiftData

@available(iOS 17.0, *)


@Model
final class MealRecord {
    var date: Date = Date()
    var mealType: String = ""
    var imageFileName: String?
    var totalCalories: Int = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var fiberGrams: Double?
    var foodDescription: String = ""
    var aiModelUsed: String?
    var createdAt: Date = Date()

    init() {}
}
