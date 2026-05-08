import Foundation

// MARK: - StorageServiceFactory
// 根据系统版本返回对应实现
enum StorageServiceFactory {
    static func makeDefault() -> StorageService {
        if #available(iOS 17, *) {
            return SwiftDataStorageService()
        } else {
            return CoreDataStorageService()
        }
    }
}
