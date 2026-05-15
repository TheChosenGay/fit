import SwiftUI
import Combine
import SwiftData

@available(iOS 17.0, *)
@MainActor
final class DietViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    private let analysisService: DietAnalysisService = ZhipuDietAnalysisService.shared

    func analyzeMeal(image: UIImage, mealType: String, context: ModelContext) async -> MealRecord? {
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let result = try await analysisService.analyze(image: image)

            let record = MealRecord()
            record.date = Date()
            record.mealType = mealType
            record.totalCalories = result.totalCalories
            record.proteinGrams = result.proteinGrams
            record.carbsGrams = result.carbsGrams
            record.fatGrams = result.fatGrams
            record.foodDescription = result.description

            // Save image
            if let fileName = try? LocalPhotoStorageService().save(image: image) {
                record.imageFileName = fileName
            }

            try DefaultDietDataService().saveMeal(record, context: context)
            return record
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
