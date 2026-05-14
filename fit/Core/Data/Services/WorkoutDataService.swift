import Foundation
import SwiftData


@available(iOS 17.0, *)
protocol WorkoutDataService {
    func saveSession(_ session: WorkoutSession, context: ModelContext) throws
    func fetchRecentSessions(days: Int, context: ModelContext) throws -> [WorkoutSession]
    func fetchSessions(from start: Date, to end: Date, context: ModelContext) throws -> [WorkoutSession]
}

@available(iOS 17.0, *)
struct DefaultWorkoutDataService: WorkoutDataService {
    func saveSession(_ session: WorkoutSession, context: ModelContext) throws {
        context.insert(session)
        try context.save()
    }

    func fetchRecentSessions(days: Int, context: ModelContext) throws -> [WorkoutSession] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.predicate = #Predicate { $0.date >= startDate }
        return try context.fetch(descriptor)
    }

    func fetchSessions(from start: Date, to end: Date, context: ModelContext) throws -> [WorkoutSession] {
        var descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date, order: .forward)])
        descriptor.predicate = #Predicate { $0.date >= start && $0.date <= end }
        return try context.fetch(descriptor)
    }
}
