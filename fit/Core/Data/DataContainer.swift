import SwiftData

final class DataContainer {
    @available(iOS 17.0, *)
    static let shared = DataContainer()

    @available(iOS 17.0, *)
    private init() {}

    private var _container: Any?

    @available(iOS 17.0, *)
    var container: ModelContainer {
        if let existing = _container as? ModelContainer {
            return existing
        }
        let schema = Schema([
            UserProfile.self,
            HealthCondition.self,
            DailyHealthData.self,
            WeightRecord.self,
            PoseAnalysisRecord.self,
            PoseIssue.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            MealRecord.self,
            TrainingPlan.self,
            PlannedSession.self,
            ProgressReport.self,
            StandardSequenceCatalog.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        _container = modelContainer
        return modelContainer
    }
}
