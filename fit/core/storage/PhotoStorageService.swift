import UIKit

// MARK: - PhotoStorageService
protocol PhotoStorageService {
    /// 保存图片到本地，返回文件名（用于后续检索）
    func save(image: UIImage) throws -> String
    /// 根据文件名加载图片
    func load(fileName: String) -> UIImage?
    /// 根据文件名删除图片
    func delete(fileName: String) throws
}
