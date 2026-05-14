import Foundation
import SwiftData


@available(iOS 17.0, *)
protocol UserDataService {
    func fetchProfile(context: ModelContext) throws -> UserProfile?
    func saveProfile(_ profile: UserProfile, context: ModelContext) throws
    func fetchWeightHistory(context: ModelContext) throws -> [WeightRecord]
    func addWeightRecord(_ record: WeightRecord, context: ModelContext) throws
}

@available(iOS 17.0, *)
struct DefaultUserDataService: UserDataService {
    func fetchProfile(context: ModelContext) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try context.fetch(descriptor).first
    }

    func saveProfile(_ profile: UserProfile, context: ModelContext) throws {
        profile.updatedAt = Date()
        context.insert(profile)
        try context.save()
    }

    func fetchWeightHistory(context: ModelContext) throws -> [WeightRecord] {
        let descriptor = FetchDescriptor<WeightRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func addWeightRecord(_ record: WeightRecord, context: ModelContext) throws {
        context.insert(record)
        try context.save()
    }
}
