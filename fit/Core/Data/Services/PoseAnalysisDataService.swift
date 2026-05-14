import Foundation
import SwiftData


@available(iOS 17.0, *)
protocol PoseAnalysisDataService {
    func fetchRecent(count: Int, context: ModelContext) throws -> [PoseAnalysisRecord]
    func saveAnalysis(_ record: PoseAnalysisRecord, context: ModelContext) throws
    func deleteAnalysis(_ record: PoseAnalysisRecord, context: ModelContext) throws
}

@available(iOS 17.0, *)
struct DefaultPoseAnalysisDataService: PoseAnalysisDataService {
    func fetchRecent(count: Int, context: ModelContext) throws -> [PoseAnalysisRecord] {
        var descriptor = FetchDescriptor<PoseAnalysisRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = count
        return try context.fetch(descriptor)
    }

    func saveAnalysis(_ record: PoseAnalysisRecord, context: ModelContext) throws {
        context.insert(record)
        try context.save()
    }

    func deleteAnalysis(_ record: PoseAnalysisRecord, context: ModelContext) throws {
        context.delete(record)
        try context.save()
    }
}
