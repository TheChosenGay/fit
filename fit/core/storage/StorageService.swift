import Foundation

// MARK: - StorageService 协议
// 抽象存储层，屏蔽 Core Data / SwiftData 实现差异
protocol StorageService {
    func save<T: Codable>(_ object: T, forKey key: String) throws
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    func delete(forKey key: String) throws
}
