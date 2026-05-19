import SwiftUI
import Combine
import SwiftData

@available(iOS 17.0, *)
@MainActor
final class DietViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    private let analysisService: DietAnalysisService = {
        // Auto-select provider based on available API keys
        if Secrets.minimaxAPIKey != "YOUR_MINIMAX_API_KEY" {
            return MiniMaxDietAnalysisService.shared
        }
        if Secrets.zhipuAPIKey != "YOUR_ZHIPU_API_KEY" {
            return ZhipuDietAnalysisService.shared
        }
        // Default: MiniMax (most commonly available)
        return MiniMaxDietAnalysisService.shared
    }()

    func analyzeMeal(image: UIImage, mealType: String, context: ModelContext) async -> MealRecord? {
        await analyzeMeal(image: image, mealType: mealType, volumeML: nil, context: context)
    }

    /// Analyze meal with optional LiDAR-measured volume per food item.
    /// `volumeML`: foodName → measured volume in ml. nil or empty = skip volume correction.
    func analyzeMeal(
        image: UIImage,
        mealType: String,
        volumeML: [String: Float]?,
        context: ModelContext
    ) async -> MealRecord? {
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let result = try await analysisService.analyze(image: image)
            return try await saveAnalyzedMeal(result: result, image: image, mealType: mealType, volumeML: volumeML, context: context)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Save a pre-analyzed meal result without re-running AI analysis.
    /// Use when the caller already has the MealAnalysisResult (e.g., captured from camera flow).
    func saveAnalyzedMeal(
        result: MealAnalysisResult,
        image: UIImage,
        mealType: String,
        volumeML: [String: Float]?,
        context: ModelContext
    ) async throws -> MealRecord? {
        let adjustedResult: MealAnalysisResult
        if let items = result.itemBreakdown, let volume = volumeML, !volume.isEmpty {
            adjustedResult = applyVolumeCorrection(result, volume: volume)
        } else {
            adjustedResult = result
        }

        let record = MealRecord()
        record.date = Date()
        record.mealType = mealType
        record.totalCalories = adjustedResult.totalCalories
        record.proteinGrams = adjustedResult.proteinGrams
        record.carbsGrams = adjustedResult.carbsGrams
        record.fatGrams = adjustedResult.fatGrams
        record.foodDescription = buildDescription(result: adjustedResult, hasVolume: volumeML != nil && volumeML?.isEmpty == false)

        if let fileName = try? LocalPhotoStorageService().save(image: image) {
            record.imageFileName = fileName
        }

        try DefaultDietDataService().saveMeal(record, context: context)
        return record
    }

    // MARK: Private

    private func applyVolumeCorrection(
        _ result: MealAnalysisResult,
        volume: [String: Float]
    ) -> MealAnalysisResult {
        guard let items = result.itemBreakdown else { return result }

        let db = FoodDensityDB.shared
        var newItems: [ItemNutrition] = []
        var totalCalories = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0

        for item in items {
            let measuredML = volume[item.name] ?? Float(item.estimatedGrams) / (db.density(for: item.name) ?? db.defaultDensity)
            let density = db.density(for: item.name) ?? db.defaultDensity
            let measuredGrams = Int(measuredML * density)

            let corrected = ItemNutrition(
                name: item.name,
                ingredients: item.ingredients,
                estimatedGrams: measuredGrams,
                kcalPer100g: item.kcalPer100g
            )
            newItems.append(corrected)

            let itemKcal = Int(Double(measuredGrams) / 100.0 * item.kcalPer100g)
            totalCalories += itemKcal

            // Distribute macros proportionally by gram ratio
            let ratio = item.estimatedGrams > 0
                ? Double(measuredGrams) / Double(item.estimatedGrams)
                : 1.0
            totalProtein += (result.proteinGrams / Double(items.count)) * ratio
            totalCarbs += (result.carbsGrams / Double(items.count)) * ratio
            totalFat += (result.fatGrams / Double(items.count)) * ratio
        }

        return MealAnalysisResult(
            foodItems: result.foodItems,
            itemBreakdown: newItems,
            totalCalories: totalCalories > 0 ? totalCalories : result.totalCalories,
            proteinGrams: totalProtein > 0 ? totalProtein : result.proteinGrams,
            carbsGrams: totalCarbs > 0 ? totalCarbs : result.carbsGrams,
            fatGrams: totalFat > 0 ? totalFat : result.fatGrams,
            description: result.description
        )
    }

    private func buildDescription(result: MealAnalysisResult, hasVolume: Bool) -> String {
        var parts = [result.description]
        if hasVolume, let items = result.itemBreakdown {
            let grams = items.map { "\($0.name) \($0.estimatedGrams)g" }.joined(separator: "、")
            parts.append("[实测] \(grams)")
        }
        return parts.joined(separator: " ")
    }
}
