import Foundation

// MARK: - CoreDataStorageService (iOS 16+)
final class CoreDataStorageService: StorageService {
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(object)
        UserDefaults.standard.set(data, forKey: key)
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func delete(forKey key: String) throws {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
